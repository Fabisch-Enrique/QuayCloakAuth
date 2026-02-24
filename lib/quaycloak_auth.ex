defmodule QuaycloakAuth do
  @moduledoc false

  def config(%Plug.Conn{private: %{phoenix_endpoint: endpoint}}),
    do: Application.fetch_env!(endpoint.config(:otp_app), __MODULE__)

  def config(otp_app) when is_atom(otp_app), do: Application.fetch_env!(otp_app, __MODULE__)

  def callbacks(conn_or_otp_app), do: config(conn_or_otp_app) |> Keyword.fetch!(:callbacks)

  def routes(conn_or_otp_app) do
    config(conn_or_otp_app)
    |> Keyword.get(:routes, %{})
    |> Map.new()
    |> Map.merge(%{
      login_path: "/auth/login",
      after_login_path: "/",
      after_logout_path: "/"
    })
  end
end
