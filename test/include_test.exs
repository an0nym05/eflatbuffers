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
                                    }, %{include: ["include_child.fbs"], root_type: :Parent}}

  @expected_simple_include_2_child {%{
                                      Child:
                                        {:table,
                                         %{
                                           fields: [name: {:string, %{}}],
                                           indices: %{name: {0, {:string, %{}}}}
                                         }},
                                      Parent: {
                                        :table,
                                        %{
                                          fields: [
                                            {:child, {:table, %{name: :Child}}},
                                            {:child2, {:table, %{name: :Child2}}}
                                          ],
                                          indices: %{
                                            child: {0, {:table, %{name: :Child}}},
                                            child2: {1, {:table, %{name: :Child2}}}
                                          }
                                        }
                                      },
                                      Child2:
                                        {:table,
                                         %{
                                           fields: [name: {:string, %{}}],
                                           indices: %{name: {0, {:string, %{}}}}
                                         }}
                                    },
                                    %{
                                      include: ["include_child.fbs", "include_child2.fbs"],
                                      root_type: :Parent
                                    }}
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
                          }, %{include: ["include_loop_b.fbs"], root_type: :LoopA}}

  test "simple include, 1 child" do
    schema =
      File.read!("test/schemas/include_parent.fbs")
      |> Eflatbuffers.Schema.parse!(base_path: "test/schemas")

    assert @expected_simple_include_1_child == schema
  end

  test "simple include, 2 childs" do
    schema =
      File.read!("test/schemas/include_parent2.fbs")
      |> Eflatbuffers.Schema.parse!(base_path: "test/schemas")

    assert @expected_simple_include_2_child == schema
  end

  test "loop is stopped" do
    schema =
      File.read!("test/schemas/include_loop_a.fbs")
      |> Eflatbuffers.Schema.parse!(base_path: "test/schemas")

    assert schema == @expected_loop_stopped
  end
end
