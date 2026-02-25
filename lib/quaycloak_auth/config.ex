defmodule QuaycloakAuth.Config do
  @moduledoc false

  @required_keys [
    :realm,
    :routes,
    :client_id,
    :client_secret
  ]

  def fetch!(app_name) when is_atom(app_name) do
    cfg = Application.fetch_env!(app_name, QuaycloakAuth)

    Enum.each(@required_keys, fn k ->
      if Keyword.has_key?(cfg, k) == false do
        raise """
        Missing QuaycloakAuth config key #{inspect(k)} for app_name #{inspect(app_name)}.

        Example:

          config #{inspect(app_name)}, QuaycloakAuth,

          realm: "current-realm",
          client_id: "client-id",
          client_secret: "client-secret"
          callbacks: HostApp.KeycloakCallbacks,
          routes: %{
          base_url: "https://keycloak.example.com",
          token_url: "https://keycloak.example.com/token",
          introspect_url: "https://keycloak.example.com/introspect"
        }
        """
      end
    end)

    cfg
  end
end
