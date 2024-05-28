defmodule Eflatbuffers.IncludeTest do
  use ExUnit.Case

  @expected_simple_include_1_child {%{
                                      Child:
                                        {:table,
                                         %{
                                           fields: [name: {:string, %{}}],
                                           indices: %{name: {0, {:string, %{}}}}
                                         }},
                                      Parent:
                                        {:table,
                                         %{
                                           fields: [child: {:table, %{name: :Child}}],
                                           indices: %{child: {0, {:table, %{name: :Child}}}}
                                         }}
                                    }, %{include: "include_child.fbs", root_type: :Parent}}

  @expected_loop_stopped {%{
                            LoopB:
                              {:table,
                               %{
                                 fields: [loop_a: {:table, %{name: :LoopA}}],
                                 indices: %{loop_a: {0, {:table, %{name: :LoopA}}}}
                               }},
                            LoopA:
                              {:table,
                               %{
                                 fields: [loop_b: {:table, %{name: :LoopB}}],
                                 indices: %{loop_b: {0, {:table, %{name: :LoopB}}}}
                               }}
                          }, %{include: "include_loop_b.fbs", root_type: :LoopA}}

  test "simple include, 1 child" do
    schema =
      File.read!("test/schemas/include_parent.fbs")
      |> Eflatbuffers.Schema.parse!(%{base_path: "test/schemas"})

    assert @expected_simple_include_1_child == schema
  end

  test "loop is stopped" do
    schema =
      File.read!("test/schemas/include_loop_a.fbs")
      |> Eflatbuffers.Schema.parse!(%{base_path: "test/schemas"})

    assert schema == @expected_loop_stopped
  end
end
