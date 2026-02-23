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

  def fetch!(otp_app) when is_atom(otp_app) do
    cfg = Application.fetch_env!(otp_app, QuaycloakAuth)

    Enum.each(@required_keys, fn k ->
      if Keyword.has_key?(cfg, k) == false do
        raise """
        Missing QuaycloakAuth config key #{inspect(k)} for otp_app #{inspect(otp_app)}.

        Example:

          config #{inspect(otp_app)}, QuaycloakAuth,

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
