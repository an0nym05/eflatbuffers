defmodule EflatbuffersTest.Fuzz do
  use ExUnit.Case
  import TestHelpers

  test "fuzz based on doge schemas" do
    [:config, :game_state, :battle_log, :commands]
    |> Enum.map(fn type -> {:doge, type} end)
    |> Enum.each(fn doge_type -> fuzz_schema(doge_type) end)
  end

  def fuzz_schema(schema_type) do
    map = Eflatbuffers.Generator.map_from_schema(load_schema(schema_type))
    fb = Eflatbuffers.write!(map, load_schema(schema_type))
    map_re = Eflatbuffers.read!(fb, load_schema(schema_type))

    {_, opts} = Eflatbuffers.parse_schema!(load_schema(schema_type))
    ns = case opts do
      %{namespace: ns} -> ns
      _ -> nil
    end

    assert [] ==
             compare_with_defaults(
               round_floats(map),
               round_floats(map_re),
               Eflatbuffers.parse_schema!(load_schema(schema_type)),
               ns
             )

    assert_full_circle_with_ns(schema_type, map, ns)
  end
end
