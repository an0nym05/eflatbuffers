defmodule EflatbuffersTest.Enums do
  use ExUnit.Case

  @enums_start_with_1 {
    %{
      E: {:enum, %{type: {:byte, %{default: 1}}, members: %{1 => :A, 2 => :B, :A => 1, :B => 2}}},
      T:
        {:table,
         %{
           fields: [e: {:enum, %{default: 1, name: :E}}],
           indices: %{e: {0, {:enum, %{default: 1, name: :E}}}}
         }}
    },
    %{root_type: :T}
  }

  test "enums start with 1" do
    schema =
      File.read!("test/schemas/enums.fbs")
      |> Eflatbuffers.parse_schema!()
      |> Eflatbuffers.Utils.with_default_ns()

    assert schema == @enums_start_with_1
  end
end
