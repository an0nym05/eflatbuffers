defmodule Eflatbuffers.Schema do
  @referenced_types [
    :string,
    :byte,
    :ubyte,
    :bool,
    :short,
    :ushort,
    :int,
    :int8,
    :uint8,
    :int16,
    :uint16,
    :int32,
    :uint32,
    :int64,
    :uint64,
    :uint,
    :float,
    :float32,
    :float64,
    :long,
    :ulong,
    :double
  ]

  def parse!(schema_str, parse_opts \\ []) do
    case parse(schema_str, parse_opts) do
      {:ok, schema} ->
        schema

      {:error, error} ->
        throw({:error, error})
    end
  end

  def parse(schema_str, parse_opts \\ []) when is_binary(schema_str) do
    tokens = lexer(schema_str)

    case :schema_parser.parse(tokens) do
      {:ok, data} ->
        {:ok, decorate(data, parse_opts)}

      error ->
        error
    end
  end

  def lexer(schema_str) do
    {:ok, tokens, _} =
      to_charlist(schema_str)
      |> :schema_lexer.string()

    tokens
  end

  def decorate_ns(entities, _ns) do
    Enum.reduce(entities, %{}, fn
      {k, {t, opts}}, acc ->
        Map.put(acc, k, {t, opts})
    end)
  end

  def process_includes(entities, options, parse_opts, included_files \\ MapSet.new()) do
    base_path = Keyword.get(parse_opts, :base_path, ".")

    case options do
      %{include: includes} ->
        ns =
          case options do
            %{namespace: ns} -> ns
            _ -> nil
          end

        Enum.reduce(
          includes,
          {entities, []},
          fn
            included_file, {acc, ordering} ->
              if MapSet.member?(included_files, included_file) do
                # Already included the file
                {acc, ordering}
              else
                {:ok, {es, options}} =
                  File.read!(Path.join(base_path, included_file))
                  |> lexer()
                  |> :schema_parser.parse()

                included_ns =
                  case options do
                    %{namespace: included_ns} -> included_ns
                    _ -> nil
                  end

                included_files = MapSet.put(included_files, included_file)

                {included_es, child_ordering} =
                  process_includes(%{included_ns => es}, options, parse_opts, included_files)

                acc =
                  Map.merge(acc, included_es, fn _, lv, rv ->
                    Map.merge(lv, rv)
                  end)

                {acc, ordering ++ child_ordering ++ [ns, included_ns]}
              end
          end
        )

      %{namespace: ns} ->
        {entities, [ns]}

      _ ->
        {entities, [nil]}
    end
  end

  def resolver(entities, ns, g) do
    ord = %{enum: 0, union: 1, table: 2, bool: 3, string: 4}

    sort_entities = fn {l, _}, {r, _} ->
      Map.get(ord, l, 99) < Map.get(ord, r, 99)
    end

    entities
    |> Enum.sort(sort_entities)
    |> Enum.reduce(
      %{},
      # for a tables we transform
      # the types to explicitly signify
      # vectors, tables, and enums
      fn
        {key, {:table, fields}}, acc ->
          v = {:table, table_options(fields, entities, ns, g)}
          Map.put(acc, key, v)

        # for enums we change the list of options
        # into a map for faster lookup when
        # writing and reading
        {key, {{:enum, type}, fields}}, acc ->
          {hash, default, _} =
            Enum.reduce(
              fields,
              {%{}, nil, 0},
              fn
                {field, value}, {hash_acc, last_default, _} ->
                  last_default =
                    case last_default do
                      nil -> value
                      n -> n
                    end

                  case Map.get(hash_acc, value) do
                    nil ->
                      m = Map.put(hash_acc, field, value) |> Map.put(value, field)
                      {m, last_default, value + 1}

                    f ->
                      raise(
                        "eflatbuffers: the enum #{field} with value #{value} has already been used by enum #{f}"
                      )
                  end

                field, {hash_acc, last_default, index} ->
                  m = Map.put(hash_acc, field, index) |> Map.put(index, field)
                  {m, last_default, index + 1}
              end
            )

          default =
            case default do
              nil -> 0
              n -> n
            end

          Map.put(acc, key, {:enum, %{type: {type, %{default: default}}, members: hash}})

        {key, {:union, fields}}, acc ->
          hash =
            Enum.reduce(
              Enum.with_index(fields),
              %{},
              fn
                {field, index}, hash_acc ->
                  Map.put(hash_acc, field, index) |> Map.put(index, field)
              end
            )

          Map.put(acc, key, {:union, %{members: hash}})
      end
    )
  end

  # this preprocesses the schema
  # in order to keep the read/write
  # code as simple as possible
  # correlate tables with names
  # and define defaults explicitly
  def decorate({entities, options}, parse_opts \\ []) do
    entities =
      case options do
        %{namespace: ns} -> %{ns => entities}
        _ -> %{nil => entities}
      end

    {entities, ordering} = process_includes(entities, options, parse_opts)

    entities_decorated =
      ordering
      |> Enum.reduce(
        %{},
        fn ns, g ->
          if Map.has_key?(g, ns) do
            g
          else
            es = Map.get(entities, ns)
            Map.put(g, ns, resolver(es, ns, g))
          end
        end
      )

    {entities_decorated, options}
  end

  def table_options(fields, entities, ns, g) do
    fields_and_indices(fields, entities, ns, g, {0, [], %{}})
  end

  def fields_and_indices([], _, _, _, {_, fields, indices}) do
    %{fields: Enum.reverse(fields), indices: indices}
  end

  def fields_and_indices(
        [{field_name, field_value} | fields],
        entities,
        ns,
        g,
        {index, fields_acc, indices_acc}
      ) do
    index_offset = index_offset(field_value, entities)
    decorated_type = decorate_field(field_value, entities, ns, g)
    index_new = index + index_offset
    fields_acc_new = [{field_name, decorated_type} | fields_acc]
    indices_acc_new = Map.put(indices_acc, field_name, {index, decorated_type})
    fields_and_indices(fields, entities, ns, g, {index_new, fields_acc_new, indices_acc_new})
  end

  def index_offset(field_value, entities) do
    case is_referenced?(field_value) do
      true ->
        case Map.get(entities, field_value) do
          {:union, _} ->
            2

          _ ->
            1
        end

      false ->
        1
    end
  end

  def decorate_field({:vector, type}, entities, ns, g) do
    {:vector, %{type: decorate_field(type, entities, ns, g)}}
  end

  def decorate_field(field_value, entities, ns, g) do
    case is_referenced?(field_value) do
      true ->
        decorate_referenced_field(field_value, entities, ns, g)

      false ->
        decorate_field(field_value)
    end
  end

  def base_ns(s) do
    String.split(to_string(s), ".")
    |> Enum.reverse()
    |> then(fn [h | tl] ->
      {Enum.reverse(tl) |> Enum.join(".") |> String.to_atom(), String.to_atom(h)}
    end)
  end

  def retrieve_ns_entity(field_value, entities, ns, g) do
    case {ns, base_ns(field_value)} do
      {nil, _} ->
        Map.get(entities, field_value)

      {_, {:"", field_value}} ->
        Map.get(entities, field_value)

      {_, {value_ns, field_value}} ->
        ns = Map.get(g, value_ns)
        Map.get(ns, field_value)
    end
  end

  def decorate_referenced_field(field_value, entities, ns, g) do
    {field_value, default} =
      case field_value do
        {field_value, default} -> {field_value, default}
        field_value -> {field_value, nil}
      end

    case retrieve_ns_entity(field_value, entities, ns, g) do
      nil ->
        throw({:error, {:entity_not_found, field_value}})

      {:table, _} ->
        {:table, %{name: field_value}}

      {{:enum, _}, _} ->
        if default != nil do
          {:enum, %{name: field_value, default: default}}
        else
          {:enum, %{name: field_value}}
        end

      {:union, _} ->
        {:union, %{name: field_value}}
    end
  end

  def decorate_field({type, default}) do
    {type, %{default: default}}
  end

  def decorate_field(:bool) do
    {:bool, %{default: false}}
  end

  def decorate_field(:string) do
    {:string, %{}}
  end

  def decorate_field(type) do
    {type, %{default: 0}}
  end

  def is_referenced?({type, _default}) do
    is_referenced?(type)
  end

  def is_referenced?(type) do
    not Enum.member?(@referenced_types, type)
  end
end
