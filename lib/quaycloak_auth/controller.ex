defmodule QuaycloakAuth.Controller do
  @moduledoc false

  use Phoenix.Controller, formats: [:html]

  require Logger

  defmacro __using__(opts) do
    app_name = Keyword.fetch!(opts, :otp_app)

    quote do
      # Keep action signatures normal: (conn, params)
      def request(conn, params),
        do: request(conn, params, unquote(app_name))

      def login(conn, params), do: login(conn, params, unquote(app_name))

      def logout(conn, params),
        do: logout(conn, params, unquote(app_name))
    end
  end

  def request(conn, _params, _app_name), do: conn

  def login(
        %{assigns: %{ueberauth_failure: %Ueberauth.Failure{errors: errors}}} = conn,
        _params,
        app_name
      ) do
    message = errors |> Enum.map(& &1.message) |> Enum.join(", ")

    Logger.warning("""
    OAUTH FAILURE

    AUTHENTICATION FAILED with REASON:: #{message} for #{app_name} APP
    """)

    conn
    |> put_flash(:error, "Authentication Failed REASON: #{message}")
    |> redirect(to: QuaycloakAuth.routes(app_name).login_path)
  end

  def login(%{assigns: %{ueberauth_auth: auth}} = conn, _params, app_name) do
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
        |> redirect(to: QuaycloakAuth.routes(app_name).login_path)
    end
  end

  def login(conn, _params, app_name) do
    conn
    |> put_flash(:error, "Login Failed")
    |> redirect(to: QuaycloakAuth.routes(app_name).login_path)
  end

  def logout(conn, _params, app_name) do
    conn
    |> QuaycloakAuth.callbacks(app_name).logout()
    |> redirect(to: QuaycloakAuth.routes(app_name).logout_path)
  end
end
