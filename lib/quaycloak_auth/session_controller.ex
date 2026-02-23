defmodule QuaycloakAuth.Controller do
  @moduledoc false

  # This module contains the actions; host controller will `use` it.
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Controller, formats: [:html]
      require Logger

      # IMPORTANT: this is compiled in the HOST APP, not the library
      plug(Ueberauth)

      def request(conn, _params), do: conn

      def login(
            %{assigns: %{ueberauth_failure: %Ueberauth.Failure{errors: errors}}} = conn,
            _params
          ) do
        message = errors |> Enum.map(& &1.message) |> Enum.join(", ")

        conn
        |> put_flash(:error, "Authentication Failed REASON: #{message}")
        |> redirect(to: QuaycloakAuth.routes(conn).login_path)
      end

      def login(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
        callbacks = QuaycloakAuth.callbacks(conn)

        with {:ok, user_info, raw_info} <- QuaycloakAuth.Ueberauth.extract(auth),
             {:ok, conn} <- callbacks.on_login(conn, user_info, raw_info) do
          redirect(conn, to: QuaycloakAuth.routes(conn).after_login_path)
        else
          {:error, reason} ->
            Logger.warning("Keycloak login failed: #{inspect(reason)}")

            conn
            |> put_flash(:error, "Login failed")
            |> redirect(to: QuaycloakAuth.routes(conn).login_path)
        end
      end

      def logout(conn, _params) do
        callbacks = QuaycloakAuth.callbacks(conn)
        conn = callbacks.on_logout(conn)
        redirect(conn, to: QuaycloakAuth.routes(conn).after_logout_path)
      end
    end
  end
end
