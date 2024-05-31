defmodule EflatbuffersTest.Comments do
  use ExUnit.Case

  @expected_person {
    %{:Person => {:table, [name: :string, age: :int]}},
    %{:root_type => :Person}
  }

  test "parse file with comments" do
    res =
      File.read!("test/schemas/comment_test.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok, @expected_person} == res
  end
end
