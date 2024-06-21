defmodule NamespaceTest do
  alias Eflatbuffers.Schema
  use ExUnit.Case

  @expected_full_ns {
    %{
      "ns.a": %{
        A: {
          :table,
          %{
            fields: [{:age, {:int, %{default: 0}}}, {:u, {:union, %{name: :U}}}],
            indices: %{age: {0, {:int, %{default: 0}}}, u: {1, {:union, %{name: :U}}}}
          }
        },
        U: {:union, %{members: %{0 => :X, 1 => :Y, 2 => :Z, :X => 0, :Y => 1, :Z => 2}}},
        X: {:table, %{fields: [x: {:int, %{default: 0}}], indices: %{x: {0, {:int, %{default: 0}}}}}},
        Y: {:table, %{fields: [y: {:float, %{default: 0}}], indices: %{y: {0, {:float, %{default: 0}}}}}},
        Z: {:table, %{fields: [z: {:byte, %{default: 0}}], indices: %{z: {0, {:byte, %{default: 0}}}}}}
      },
      "ns.b": %{
        B: {
          :table,
          %{fields: [name: {:string, %{}}, a: {:table, %{name: :"ns.a.A"}}], indices: %{a: {1, {:table, %{name: :"ns.a.A"}}}, name: {0, {:string, %{}}}}}
        }
      }
    },
    %{include: ["../a/a.fbs"], namespace: :"ns.b", root_type: :B}
  }

  test "Schema read: ns.a < ns.b" do
    b = File.read!("test/schemas/ns/b/b.fbs") |> Schema.parse!(base_path: "test/schemas/ns/b")
    assert b == @expected_full_ns
  end

  test "Full circle: ns.a < ns.b" do
    m = %{
      a: %{age: 42, u: %{x: 125}, u_type: "X"},
      name: "Age of the Universe"
    }

    schema =
      File.read!("test/schemas/ns/b/b.fbs") |> Schema.parse!(base_path: "test/schemas/ns/b")

    File.write!("out.bin", Eflatbuffers.write!(m, schema))

    assert "\x10\0\0\0\0\0\0\0\b\0\f\0\x04\0\b\0\b\0\0\0\b\0\0\0%\0\0\0\x13\0\0\0Age of the Universe\n\0\r\0\x04\0\b\0\t\0\n\0\0\0*\0\0\0\x01\n\0\0\0\x06\0\b\0\x04\0\x06\0\0\0}\0\0\0"
      == Eflatbuffers.write!(m, schema)
  end
end
