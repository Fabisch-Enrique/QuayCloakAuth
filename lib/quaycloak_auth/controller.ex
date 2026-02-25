defmodule QuaycloakAuth.Controller do
  @moduledoc false

  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      use Phoenix.Controller, formats: [:html]

      require Logger

      # Inject app_name once, so callers don't have to
      def request(conn, params) do
        params = Map.put(params || %{}, "app_name", unquote(otp_app))
        conn
      end

      def login(
            %{assigns: %{ueberauth_failure: %Ueberauth.Failure{errors: errors}}} = conn,
            params
          ) do
        params = Map.put(params || %{}, "app_name", unquote(otp_app))

        app_name = Map.fetch!(params, "app_name")
        message = errors |> Enum.map(& &1.message) |> Enum.join(", ")

        Logger.warning("""
        OAUTH FAILURE

        AUTHENTICATION FAILED with REASON:: #{message}
        """)

        conn
        |> put_flash(:error, "Authentication Failed REASON: #{message}")
        |> redirect(to: QuaycloakAuth.routes(app_name).redirect_uri)
      end

      def login(%{assigns: %{ueberauth_auth: auth}} = conn, params) do
        params = Map.put(params || %{}, "app_name", unquote(otp_app))

        app_name = Map.fetch!(params, "app_name")
        callbacks = QuaycloakAuth.callbacks(app_name)

        Logger.debug("""
        OAUTH SUCCESS

        AUTHENTICATION SUCCESSFUL...
        """)

        with {:ok, user_info, raw_info} <- QuaycloakAuth.Ueberauth.extract(auth),
             {:ok, conn} <- callbacks.login(conn, user_info, raw_info) do
          redirect(conn, to: QuaycloakAuth.routes(app_name).redirect_uri)
        else
          {:error, reason} ->
            Logger.warning("Login failed with REASON:: #{inspect(reason)}")

            conn
            |> put_flash(:error, "Login Failed")
            |> redirect(to: QuaycloakAuth.routes(app_name).redirect_uri)
        end
      end

      def login(conn, params) do
        params = Map.put(params || %{}, "app_name", unquote(otp_app))
        app_name = Map.fetch!(params, "app_name")

        conn
        |> put_flash(:error, "Login Failed")
        |> redirect(to: QuaycloakAuth.routes(app_name).redirect_uri)
      end

      def logout(conn, params) do
        params = Map.put(params || %{}, "app_name", unquote(otp_app))
        app_name = Map.fetch!(params, "app_name")

        conn
        |> QuaycloakAuth.callbacks(app_name).logout()
        |> redirect(to: QuaycloakAuth.routes(app_name).logout_path)
      end
    end
  end
end
