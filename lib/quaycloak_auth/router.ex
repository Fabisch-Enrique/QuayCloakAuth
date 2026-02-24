defmodule QuaycloakAuth.Router do
  defmacro quaycloak_callback_route(opts) do
    scope = Keyword.get(opts, :scope, "/auth")
    controller = Keyword.fetch!(opts, :controller)

    quote do
      scope unquote(scope) do
        get("/:provider/callback", unquote(controller), :login)
      end
    end
  end

  defmacro quaycloak_logout_route(opts) do
    scope = Keyword.get(opts, :scope, "/")
    controller = Keyword.fetch!(opts, :controller)

    quote do
      scope unquote(scope) do
        delete("/logout", unquote(controller), :logout)
      end
    end
  end
end
