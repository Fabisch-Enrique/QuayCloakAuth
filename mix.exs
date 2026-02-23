defmodule QuaycloakAuth.MixProject do
  use Mix.Project

  def project do
    [
      app: :quaycloak_auth,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Keycloak Auth ++ admin API toolkit for Phoenix (Ueberauth-based v1).",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {QuaycloakAuth.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.19.1"},
      {:phoenix, "~> 1.8.1"},
      {:ueberauth_keycloak_strategy, "~> 0.4.0"},
      {:vc_utils, git: "https://github.com/valuechainfactory/vc_utils.git"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Fabisch-Enrique/QuayCloakAuth"
      }
    ]
  end
end
