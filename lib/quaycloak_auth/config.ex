defmodule QuaycloakAuth.Config do
  @moduledoc false

  @required_keys [
    :realm,
    :base_url,
    :token_url,
    :client_id,
    :redirect_uri,
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

          realm: "my_realm",
          client_id: "admin-cli",
          callbacks: HostApp.KeycloakCallbacks,
          client_secret: "qweRT^%433asdFGH56",
          base_url: "https://keycloak.example.com"
        """
      end
    end)

    cfg
  end
end
