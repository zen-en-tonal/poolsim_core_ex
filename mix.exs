defmodule PoolsimCoreEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :poolsim_core_ex,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:rustler, "~> 0.37.3", runtime: false}
    ]
  end
end
