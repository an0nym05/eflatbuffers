defmodule Eflatbuffers.Schema do
  @referenced_types [
    :string,
    :byte,
    :ubyte,
    :bool,
    :short,
    :ushort,
    :int,
    :uint,
    :float,
    :long,
    :ulong,
    :double
  ]

  def parse!(schema_str) do
    case parse(schema_str) do
      {:ok, schema} ->
        schema

      {:error, error} ->
        throw({:error, error})
    end
  end

  def parse(schema_str) when is_binary(schema_str) do
    tokens = lexer(schema_str)

    case :schema_parser.parse(tokens) do
      {:ok, data} ->
        {:ok, decorate(data)}

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

  # this preprocesses the schema
  # in order to keep the read/write
  # code as simple as possible
  # correlate tables with names
  # and define defaults explicitly
  def decorate({entities, options}) do
    ord = %{enum: 0, union: 1, table: 2, bool: 3, string: 4}

    sort_entities = fn {l, _}, {r, _} ->
      Map.get(ord, l, 99) < Map.get(ord, r, 99)
    end

    entities_decorated =
      Enum.sort(entities, sort_entities)
      |> Enum.reduce(
        # entities,
        %{},
        # for a tables we transform
        # the types to explicitly signify
        # vectors, tables, and enums
        fn
          {key, {:table, fields}}, acc ->
            Map.put(
              acc,
              key,
              {:table, table_options(fields, entities)}
            )

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

    {entities_decorated, options}
  end

  def table_options(fields, entities) do
    fields_and_indices(fields, entities, {0, [], %{}})
  end

  def fields_and_indices([], _, {_, fields, indices}) do
    %{fields: Enum.reverse(fields), indices: indices}
  end

  def fields_and_indices(
        [{field_name, field_value} | fields],
        entities,
        {index, fields_acc, indices_acc}
      ) do
    index_offset = index_offset(field_value, entities)
    decorated_type = decorate_field(field_value, entities)
    index_new = index + index_offset
    fields_acc_new = [{field_name, decorated_type} | fields_acc]
    indices_acc_new = Map.put(indices_acc, field_name, {index, decorated_type})
    fields_and_indices(fields, entities, {index_new, fields_acc_new, indices_acc_new})
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

  def decorate_field({:vector, type}, entities) do
    {:vector, %{type: decorate_field(type, entities)}}
  end

  def decorate_field(field_value, entities) do
    case is_referenced?(field_value) do
      true ->
        decorate_referenced_field(field_value, entities)

      false ->
        decorate_field(field_value)
    end
  end

  def decorate_referenced_field(field_value, entities) do
    {field_value, default} =
      case field_value do
        {field_value, default} -> {field_value, default}
        field_value -> {field_value, nil}
      end

    case Map.get(entities, field_value) do
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
