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
            %{"app_name" => app_name} = _params
          ) do
        message = errors |> Enum.map(& &1.message) |> Enum.join(", ")

        """
        OAUTH FAILURE

        AUTHENTICATION FAILED with REASON:: #{message}
        """
        |> Logger.warning()

        conn
        |> put_flash(:error, "Authentication Failed REASON: #{message}")
        |> redirect(to: QuaycloakAuth.routes(app_name).login_path)
      end

      def login(%{assigns: %{ueberauth_auth: auth}} = conn, %{"app_name" => app_name}) do
        callbacks = QuaycloakAuth.callbacks(app_name)

        """
        OAUTH SUCCESS

        AUTHENTICATION SUCCESSFUL...
        """
        |> Logger.debug()

        with {:ok, user_info, raw_info} <- QuaycloakAuth.Ueberauth.extract(auth),
             {:ok, conn} <- callbacks.login(conn, user_info, raw_info) do
          redirect(conn, to: QuaycloakAuth.routes(app_name).redirect_uri)
        else
          {:error, reason} ->
            Logger.warning("Login failed with REASON:: #{inspect(reason)}")

            conn
            |> put_flash(:error, "Login Failed")
            |> redirect(to: QuaycloakAuth.routes(app_name).login_path)
        end
      end

      def logout(conn, %{"app_name" => app_name}) do
        conn
        |> QuaycloakAuth.callbacks(app_name).logout()
        |> redirect(to: QuaycloakAuth.routes(app_name).logout_path)
      end
    end
  end
end
