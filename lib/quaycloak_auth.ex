defmodule QuaycloakAuth do
  @moduledoc false

  def config(%Plug.Conn{private: %{phoenix_endpoint: endpoint}}),
    do: Application.fetch_env!(endpoint.config(:app_name), __MODULE__)

  def config(app_name) when is_atom(app_name), do: Application.fetch_env!(app_name, __MODULE__)

  def callbacks(app_name), do: config(app_name) |> Keyword.get(:callbacks)

  def routes(app_name) do
    config(app_name)
    |> Keyword.get(:routes, %{})
    |> Map.new()
    |> Map.merge(%{
      logout_path: "/",
      redirect_uri: "/"
    })
  end
end
