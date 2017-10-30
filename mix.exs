defmodule FlexLogger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :flex_logger,
      source_url: "https://github.com/arnomi/elixir-flex-logger",
      docs: [main: FlexLogger],
      package: package(),
      version: "0.1.1",
      description: description(),
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
    [ {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:logger_file_backend, "~> 0.0.10", only: :dev}]
  end

  defp description() do
    "FlexLogger is a flexible logger (backend) adds module/application specific log levels to Elixir's Logger."
  end

  defp package() do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Arno Mittelbach"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/arnomi/elixir-flex-logger"}
    ]
  end
end