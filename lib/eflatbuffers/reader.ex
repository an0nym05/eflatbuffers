defmodule Eflatbuffers.Reader do
  alias Eflatbuffers.Utils

  def read({:bool, _options}, vtable_pointer, data, _, _) do
    case read_from_data_buffer(vtable_pointer, data, 8) do
      <<0>> -> false
      <<1>> -> true
    end
  end

  def read({:int8, options}, vtable_pointer, data, schema, ns),
    do: read({:byte, options}, vtable_pointer, data, schema, ns)

  def read({:byte, _options}, vtable_pointer, data, _, _) do
    <<value::signed-size(8)>> = read_from_data_buffer(vtable_pointer, data, 8)
    value
  end

  def read({:uint8, options}, vtable_pointer, data, schema, ns),
    do: read({:ubyte, options}, vtable_pointer, data, schema, ns)

  def read({:ubyte, _options}, vtable_pointer, data, _, _) do
    <<value::unsigned-size(8)>> = read_from_data_buffer(vtable_pointer, data, 8)
    value
  end

  def read({:int16, options}, vtable_pointer, data, schema, ns),
    do: read({:short, options}, vtable_pointer, data, schema, ns)

  def read({:short, _options}, vtable_pointer, data, _, _) do
    <<value::signed-little-size(16)>> = read_from_data_buffer(vtable_pointer, data, 16)
    value
  end

  def read({:uint16, options}, vtable_pointer, data, schema, ns),
    do: read({:ushort, options}, vtable_pointer, data, schema, ns)

  def read({:ushort, _options}, vtable_pointer, data, _, _) do
    <<value::unsigned-little-size(16)>> = read_from_data_buffer(vtable_pointer, data, 16)
    value
  end

  def read({:int32, options}, vtable_pointer, data, schema, ns),
    do: read({:int, options}, vtable_pointer, data, schema, ns)

  def read({:int, _options}, vtable_pointer, data, _, _) do
    <<value::signed-little-size(32)>> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def read({:uint32, options}, vtable_pointer, data, schema, ns),
    do: read({:uint, options}, vtable_pointer, data, schema, ns)

  def read({:uint, _options}, vtable_pointer, data, _, _) do
    <<value::unsigned-little-size(32)>> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def read({:float32, options}, vtable_pointer, data, schema, ns),
    do: read({:float, options}, vtable_pointer, data, schema, ns)

  def read({:float, _options}, vtable_pointer, data, _, _) do
    <<value::float-little-size(32)>> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def read({:int64, options}, vtable_pointer, data, schema, ns),
    do: read({:long, options}, vtable_pointer, data, schema, ns)

  def read({:long, _options}, vtable_pointer, data, _, _) do
    <<value::signed-little-size(64)>> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  def read({:uint64, options}, vtable_pointer, data, schema, ns),
    do: read({:ulong, options}, vtable_pointer, data, schema, ns)

  def read({:ulong, _options}, vtable_pointer, data, _, _) do
    <<value::unsigned-little-size(64)>> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  def read({:float64, options}, vtable_pointer, data, schema, ns),
    do: read({:double, options}, vtable_pointer, data, schema, ns)

  def read({:double, _options}, vtable_pointer, data, _, _) do
    <<value::float-little-size(64)>> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  # complex types

  def read({:string, _options}, vtable_pointer, data, _, _) do
    <<string_offset::unsigned-little-size(32)>> = read_from_data_buffer(vtable_pointer, data, 32)
    string_pointer = vtable_pointer + string_offset

    <<_::binary-size(string_pointer), string_length::unsigned-little-size(32),
      string::binary-size(string_length), _::binary>> = data

    string
  end

  def read({:vector, options}, vtable_pointer, data, schema, ns) do
    type = options.type
    <<vector_offset::unsigned-little-size(32)>> = read_from_data_buffer(vtable_pointer, data, 32)
    vector_pointer = vtable_pointer + vector_offset
    <<_::binary-size(vector_pointer), vector_count::unsigned-little-size(32), _::binary>> = data
    is_scalar = Utils.scalar?(type)
    read_vector_elements(type, is_scalar, vector_pointer + 4, vector_count, data, ns, schema)
  end

  def read({:enum, %{name: enum_name}}, vtable_pointer, data, {tables, _options} = schema, ns) do
    {:enum, options} = Map.get(tables, ns) |> Map.get(enum_name)
    members = options.members
    type = options.type
    index = read(type, vtable_pointer, data, schema, ns)

    case Map.get(members, index) do
      nil ->
        throw({:error, {:not_in_enum, index, members}})

      value_atom ->
        Atom.to_string(value_atom)
    end
  end

  # read a complete table, given a pointer to the springboard
  def read(
        {:table, %{name: table_name}},
        table_pointer_pointer,
        data,
        {tables, options} = schema,
        ns
      )
      when is_atom(table_name) do
    ns =
      case {options, ns} do
        {%{namespace: default_ns}, _} -> default_ns
        {_, ns} -> ns
      end

    {ns, table_name} = Utils.base_ns(table_name, ns)

    <<_::binary-size(table_pointer_pointer), table_offset::little-size(32), _::binary>> = data
    table_pointer = table_pointer_pointer + table_offset
    {:table, options} = Map.get(tables, ns) |> Map.get(table_name)
    fields = options.fields
    <<_::binary-size(table_pointer), vtable_offset::little-signed-size(32), _::binary>> = data
    vtable_pointer = table_pointer - vtable_offset

    <<_::binary-size(vtable_pointer), vtable_length::little-size(16),
      _data_buffer_length::little-size(16), _::binary>> = data

    vtable_fields_pointer = vtable_pointer + 4
    vtable_fields_length = vtable_length - 4

    <<_::binary-size(vtable_fields_pointer), vtable::binary-size(vtable_fields_length),
      _::binary>> = data

    data_buffer_pointer = table_pointer
    read_table_fields(fields, vtable, data_buffer_pointer, data, ns, schema)
  end

  # fail if nothing matches
  def read({type, _}, _, _, _, _, _) do
    throw({:error, {:unknown_type, type}})
  end

  def read_vector_elements(_, _, _, 0, _, _, _) do
    []
  end

  def read_vector_elements(type, true, vector_pointer, vector_count, data, ns, schema) do
    value = read(type, vector_pointer, data, schema, ns)
    offset = Utils.scalar_size(Utils.extract_scalar_type(type, schema, ns))

    [
      value
      | read_vector_elements(
          type,
          true,
          vector_pointer + offset,
          vector_count - 1,
          data,
          ns,
          schema
        )
    ]
  end

  def read_vector_elements(type, false, vector_pointer, vector_count, data, ns, schema) do
    value = read(type, vector_pointer, data, schema, ns)
    offset = 4

    [
      value
      | read_vector_elements(
          type,
          false,
          vector_pointer + offset,
          vector_count - 1,
          data,
          ns,
          schema
        )
    ]
  end

  # this is a utility that just reads data_size bytes from data after data_pointer
  def read_from_data_buffer(data_pointer, data, data_size) do
    <<_::binary-size(data_pointer), value::bitstring-size(data_size), _::binary>> = data
    value
  end

  def read_table_fields(fields, vtable, data_buffer_pointer, data, ns, schema) do
    read_table_fields(fields, vtable, data_buffer_pointer, data, ns, schema, %{})
  end

  # we might still have more fields but we ran out of vtable slots
  # this happens if the schema has more fields than the data (schema evolution)
  def read_table_fields(_, <<>>, _, _, _, _, map) do
    map
  end

  # we might have more data but no more fields
  # that means the data is ahead and has more data than the schema
  def read_table_fields([], _, _, _, _, _, map) do
    map
  end

  def read_table_fields(
        [{name, {:union, %{name: union_name}}} | fields],
        <<data_offset::little-size(16), vtable::binary>>,
        data_buffer_pointer,
        data,
        ns,
        {tables, _options} = schema,
        map
      ) do
    # for a union byte field named $fieldname$_type is prefixed
    union_index =
      read({:byte, %{default: 0}}, data_buffer_pointer + data_offset, data, schema, ns)

    case union_index do
      0 ->
        # index is null, so field is not set
        # carry on
        read_table_fields(fields, vtable, data_buffer_pointer, data, ns, schema, map)

      _ ->
        # we have a table set so we get the type and
        # expect it as the next record in the vtable
        {:union, options} = Map.get(tables, ns) |> Map.get(union_name)
        members = options.members
        union_type = Map.get(members, union_index - 1)
        union_type_key = String.to_atom(Atom.to_string(name) <> "_type")
        map_new = Map.put(map, union_type_key, Atom.to_string(union_type))

        read_table_fields(
          [{name, {:table, %{name: union_type}}} | fields],
          vtable,
          data_buffer_pointer,
          data,
          ns,
          schema,
          map_new
        )
    end
  end

  # we find a null pointer
  # so we set the dafault
  def read_table_fields(
        [{name, {:enum, options}} | fields],
        <<0, 0, vtable::binary>>,
        data_buffer_pointer,
        data,
        ns,
        {tables, _} = schema,
        map
      ) do
    {_, enum_options} = Map.get(tables, ns) |> Map.get(options.name)
    {_, %{default: default}} = enum_options.type

    map_new = Map.put(map, name, Atom.to_string(Map.get(enum_options.members, default)))
    read_table_fields(fields, vtable, data_buffer_pointer, data, ns, schema, map_new)
  end

  def read_table_fields(
        [{name, {_type, options}} | fields],
        <<0, 0, vtable::binary>>,
        data_buffer_pointer,
        data,
        ns,
        schema,
        map
      ) do
    map_new =
      case Map.get(options, :default) do
        nil -> map
        default -> Map.put(map, name, default)
      end

    read_table_fields(fields, vtable, data_buffer_pointer, data, ns, schema, map_new)
  end

  def read_table_fields(
        [{name, type} | fields],
        <<data_offset::little-size(16), vtable::binary>>,
        data_buffer_pointer,
        data,
        ns,
        schema,
        map
      ) do
    value = read(type, data_buffer_pointer + data_offset, data, schema, ns)
    map_new = Map.put(map, name, value)
    read_table_fields(fields, vtable, data_buffer_pointer, data, ns, schema, map_new)
  end
end
