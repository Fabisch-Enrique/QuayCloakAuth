defmodule QuaycloakAuth.Callbacks do
  @moduledoc """

  Host app extension points.

  The library handles Ueberauth + Keycloak token extraction.
  The host app handles:
    - creating/updating current user logging in
    - managing the DB user sessions
    - storing raw Keycloak metadata
  """

  @callback on_login(Plug.Conn.t(), user_info :: map(), raw_info :: map()) ::
              {:ok, Plug.Conn.t()} | {:error, term()}

  @callback on_logout(Plug.Conn.t()) :: Plug.Conn.t()
end
