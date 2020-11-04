defmodule DhtSimulator.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.2.4",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:logger_file_backend, "~> 0.0.11"}
    ]
  end
end
