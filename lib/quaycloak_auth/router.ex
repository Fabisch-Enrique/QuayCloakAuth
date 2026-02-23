defmodule QuaycloakAuth.Router do
  defmacro keycloak_auth_routes(opts \\ []) do
    scope = Keyword.get(opts, :scope, "/")
    controller = Keyword.get(opts, :controller, QuaycloakAuthWeb.SessionController)

    quote do
      scope unquote(scope) do
        delete("/logout", unquote(controller), :logout)
        get("/auth/keycloak", unquote(controller), :request)
        get("/auth/keycloak/callback", unquote(controller), :login)
      end
    end
  end
end
