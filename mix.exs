defmodule Eflatbuffers.Mixfile do
  use Mix.Project

  def project do
    [
      app: :eflatbuffers,
      version: "0.1.0",
      description: description(),
      package: package(),
      elixir: ">= 1.1.1",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_file: {:no_warn, "priv/plts/project.plt"}
      ],
      compilers: [:leex, :yecc] ++ Mix.compilers()
    ]
  end

  defp package() do
    [
      name: "eflatbuffers",
      files: ["config", "lib", "src", "test", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Florian Odronitz"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/odo/eflatbuffers"},
      source_url: "https://github.com/odo/eflatbuffers"
    ]
  end

  defp description() do
    "This is a flatbuffers implementation in Elixir.
    In contrast to existing implementations there is no need to compile code from a schema. Instead, data and schemas are processed dynamically at runtime, offering greater flexibility."
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger], extra_applications: [:crypto]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:flatbuffer_port,
       git: "https://github.com/reimerei/elixir-flatbuffers",
       branch: "master",
       only: :test,
       override: true},
      {:poison, "~> 5.0.0", only: :test, override: true},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
