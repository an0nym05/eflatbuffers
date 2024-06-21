defmodule Eflatbuffers.Utils do
  def scalar?({type, _options}), do: scalar?(type)
  def scalar?(:string), do: false
  def scalar?(:vector), do: false
  def scalar?(:table), do: false
  def scalar?(:enum), do: true
  def scalar?(_), do: true

  def scalar_size({type, _options}), do: scalar_size(type)
  def scalar_size(:byte), do: 1
  def scalar_size(:ubyte), do: 1
  def scalar_size(:bool), do: 1
  def scalar_size(:short), do: 2
  def scalar_size(:ushort), do: 2
  def scalar_size(:int), do: 4
  def scalar_size(:uint), do: 4
  def scalar_size(:int8), do: 1
  def scalar_size(:uint8), do: 1
  def scalar_size(:int16), do: 2
  def scalar_size(:uint16), do: 2
  def scalar_size(:int32), do: 4
  def scalar_size(:uint32), do: 4
  def scalar_size(:int64), do: 8
  def scalar_size(:uint64), do: 8
  def scalar_size(:float), do: 4
  def scalar_size(:float32), do: 4
  def scalar_size(:float64), do: 8
  def scalar_size(:long), do: 8
  def scalar_size(:ulong), do: 8
  def scalar_size(:double), do: 8
  def scalar_size(type), do: throw({:error, {:unknown_scalar, type}})

  def extract_scalar_type({:enum, %{name: enum_name}}, {tables, _options}, ns) do
    {:enum, %{type: type}} = Map.get(tables, ns) |> Map.get(enum_name)
    type
  end

  def extract_scalar_type(type, _, _), do: type

  def base_ns(s, default_ns \\ nil) do
    s =
      case is_atom(s) do
        true -> Atom.to_string(s)
        _ -> s
      end

    String.split(s, ".")
    |> Enum.reverse()
    |> then(fn [h | tl] ->
      h =
        case h do
          # remap empty string to nil
          "" -> nil
          _ -> String.to_atom(h)
        end

      ns_path =
        case tl do
          [] -> default_ns
          _ -> Enum.reverse(tl) |> Enum.join(".") |> String.to_atom()
        end

      {ns_path, h}
    end)
  end

  def with_default_ns({entities, opts}) do
    {Map.get(entities, nil), opts}
  end

  def get_namespace(opts) do
    case opts do
      %{namespace: ns} -> ns
      _ -> nil
    end
  end

  def fetch_with_ns({entities, opts}, ns) do
    case Map.fetch(entities, ns) do
      :error ->
        base_ns = get_namespace(opts)
        msg = if ns == nil do
          "Default empty namespace was not found, maybe you meant #{base_ns}?"
        else
          "Namespace #{ns} was not found, or did not contain any entities. Maybe you meant #{base_ns}"
        end
        {:error, msg}
      {:ok, entities} -> {:ok, {entities, opts}}
    end
  end
end
