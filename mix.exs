defmodule FlexLogger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :flex_logger,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths() ++ ["test/support"]
  defp elixirc_paths(_), do: elixirc_paths()
  defp elixirc_paths(), do: ["lib"]

  # Type `mix help deps` for more examples and options
  defp deps do
    [ {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}]
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "flex_logger",
      # These are the default files included in the package
      files: ["lib", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
      maintainers: ["Arno Mittelbach"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/elixir-ecto/postgrex"}
    ]
  end
end