defmodule QuaycloakAuth.Controller do
  @moduledoc false

  # This module contains the actions; host controller will `use` it.
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Controller, formats: [:html]

      require Logger

      def request(conn, _params), do: conn

      def login(
            %{assigns: %{ueberauth_failure: %Ueberauth.Failure{errors: errors}}} = conn,
            _params
          ) do
        message = errors |> Enum.map(& &1.message) |> Enum.join(", ")

        """
        OAUTH FAILURE

        AUTHENTICATION FAILED with REASON:: #{message}
        """
        |> Logger.warning()

        conn
        |> put_flash(:error, "Authentication Failed REASON: #{message}")
        |> redirect(to: QuaycloakAuth.routes(conn).login_path)
      end

      def login(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
        callbacks = QuaycloakAuth.callbacks(conn)

        """
        OAUTH SUCCESS

        AUTHENTICATION SUCCESSFUL....
        """
        |> Logger.debug()

        with {:ok, user_info, raw_info} <- QuaycloakAuth.Ueberauth.extract(auth),
             {:ok, conn} <- callbacks.login(conn, user_info, raw_info) do
          redirect(conn, to: QuaycloakAuth.routes(conn).redirect_uri)
        else
          {:error, reason} ->
            Logger.warning("Login failed with REASON:: #{inspect(reason)}")

            conn
            |> put_flash(:error, "Login Failed")
            |> redirect(to: QuaycloakAuth.routes(conn).login_path)
        end
      end

      def logout(conn) do
        conn
        |> QuaycloakAuth.callbacks().logout()
        |> redirect(to: QuaycloakAuth.routes(conn).logout_path)
      end
    end
  end
end
