defmodule EflatbuffersTest.Enums do
  use ExUnit.Case

  @enums_start_with_1 {%{}}

  test "enums start with 1" do
    schema = File.read!("test/schemas/enums.fbs") |> Eflatbuffers.parse_schema!()
    assert schema == @enums_start_with_1
  end
end
