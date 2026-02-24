defmodule QuaycloakAuth.Admin.User do
  use VCUtils.HTTPClient

  require Logger

  alias QuaycloakAuth.Admin.Client

  @required_actions ["UPDATE_PASSWORD"]

  def config(),
    do:
      :ueberauth
      |> Application.get_env(Ueberauth.Strategy.Keycloak.OAuth)
      |> check_config_keys_exist(:client_id)
      |> check_config_keys_exist(:client_secret)

  def config(key), do: config() |> Keyword.get(key)

  def create_user_and_send_email_actions(attrs)
      when is_map(attrs) do
    payload =
      %{
        email: attrs.email,
        firstName: attrs.first_name,
        lastName: attrs.last_name,
        requiredActions: @required_actions,
        enabled: Map.get(attrs, :enabled, true),
        emailVerified: Map.get(attrs, :email_verified, false)
      }
      |> Jason.encode!()

    url = "#{config(:base_url)}/admin/realms/#{config(:realm)}/users"
    opts = %{client_id: "locus", redirect_uri: "https://locus.evisa.go.ke"}

    with {:ok, token_body} <- Client.get_token(),
         headers = [
           {"Authorization", "Bearer #{token_body.access_token}"},
           {"Content-Type", "application/json"}
         ],
         {:ok, %{status: 201, body: _body}} <- request(:post, url, payload, headers),
         {:ok, user_id} <- get_user_id_by_email(attrs.email, token_body.access_token) do
      Task.start(fn ->
        # send_verify_email(user_id, opts)
        send_update_password_email(user_id, opts)
      end)

      Logger.warning("""
      User Created Successfully.

      Update Password email has been sent.
      """)

      {:ok, user_id}
    else
      false ->
        {:error, :unexpected_status}

      {:ok, %{status: status, body: body}} ->
        {:error, {:keycloak_error, status, body}}

      {:error, %{status: 409, body: %{errorMessage: message}}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_user_id_by_email(email, token) do
    url =
      "#{config(:base_url)}/admin/realms/#{config(:realm)}/users" <>
        "?email=#{URI.encode(email)}&exact=true"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    with {:ok, %{status: 200, body: [%{id: id}]}} <- request(:get, url, "", headers) do
      {:ok, id}
    else
      [] ->
        {:error, :user_not_found}

      nil ->
        {:error, :user_not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:keycloak_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def send_verify_email(user_id, opts \\ %{}),
    do: execute_actions(user_id, ["VERIFY_EMAIL"], opts)

  def send_update_password_email(user_id, opts \\ %{}),
    do: execute_actions(user_id, ["UPDATE_PASSWORD"], opts)

  @spec send_webauthn_register_email(any()) :: :ok | {:error, any()}
  def send_webauthn_register_email(user_id, opts \\ %{}),
    do: execute_actions(user_id, ["WEBAUTHN_REGISTER"], opts)

  def update_user(user_id, attrs) do
    payload =
      attrs
      |> to_keycloak_user()
      |> Jason.encode!()

    url = config(:base_url) <> "/admin/realms/" <> config(:realm) <> "/users/" <> user_id

    with {:ok, body} <- Client.get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"},
           {"Content-Type", "application/json"}
         ],
         {:ok, %{status: 204}} <- request(:put, url, payload, headers) do
      :ok
    else
      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      error ->
        error
    end
  end

  def list_groups() do
    url = config(:base_url) <> "/admin/realms/" <> config(:realm) <> "/groups"

    with {:ok, body} <- Client.get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"}
         ],
         {:ok, %{status: 200, body: body}} <- request(:get, url, "", headers) do
      {:ok, Enum.map(body, &{&1.name, &1.id})}
    end
  end

  def get_user_info(user_id) do
    url =
      "#{config(:base_url)}/admin/realms/#{config(:realm)}/users/#{user_id}"

    with {:ok, body} <- Client.get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"}
         ],
         {:ok, %{status: 200, body: body}} <- request(:get, url, "", headers) do
      {:ok,
       %{
         id: body.id || body["id"],
         email: body.email || body["email"],
         enabled: body.enabled || body["enabled"],
         username: body.username || body["username"],
         first_name: body.firstName || body["firstName"],
         last_name: body.lastName || body["lastName"],
         email_verified: body.emailVerified || body["emailVerified"],
         created_timestamp: body.createdTimestamp || body["createdTimestamp"]
       }}
    end
  end

  def get_user_groups(user_id) do
    url = "#{config(:base_url)}/admin/realms/#{config(:realm)}/users/#{user_id}/groups"

    with {:ok, body} <- Client.get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"}
         ],
         {:ok, %{status: 200, body: body}} <- request(:get, url, "", headers) do
      {:ok, Enum.map(body, &{&1.name, &1.id})}
    end
  end

  def set_user_enabled(user_id, enabled) do
    url = config(:base_url) <> "/admin/realms/" <> config(:realm) <> "/users/" <> user_id
    payload = %{enabled: enabled}

    with {:ok, body} <- Client.get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"},
           {"Content-Type", "application/json"}
         ],
         {:ok, %{status: 200, body: body}} <- request(:put, url, payload, headers) do
      {:ok, body}
    else
      {:error, body} ->
        body

      any ->
        any
    end
  end

  # --------------------- Private/Helper Functions -------------------------- #

  defp execute_actions(user_id, actions, opts) when is_list(actions) do
    url =
      "#{config(:base_url)}/admin/realms/#{config(:realm)}/users/#{user_id}/execute-actions-email" <>
        maybe_build_execute_actions_query(opts)

    with {:ok, body} <- Client.get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"},
           {"Content-Type", "application/json"}
         ],
         payload <- Jason.encode!(actions),
         {:ok, %{status: status}} <- request(:put, url, payload, headers),
         true <- status in [204] do
      :ok
    else
      false ->
        {:error, :unexpected_status}

      {:ok, %{status: _status, body: resp_body}} ->
        {:error, resp_body}

      {:error, reason} ->
        reason.body.errorMessage
    end
  end

  # Keycloak supports optional query params like client_id, redirect_uri, lifespan
  # Example opts: %{client_id: "account", redirect_uri: "https://app.example.com", lifespan: 900}
  defp maybe_build_execute_actions_query(opts) when is_map(opts) do
    params =
      opts
      |> Enum.flat_map(fn
        {:client_id, v} when is_binary(v) -> [{"client_id", v}]
        {:redirect_uri, v} when is_binary(v) -> [{"redirect_uri", v}]
        {:lifespan, v} when is_integer(v) -> [{"lifespan", Integer.to_string(v)}]
        _ -> []
      end)

    case params do
      [] -> ""
      _ -> "?" <> URI.encode_query(params)
    end
  end

  defp check_config_keys_exist(config, key) do
    cond do
      is_list(config) and Keyword.has_key?(config, key) ->
        config

      is_list(config()) ->
        raise "#{inspect(config(key))} missing from config :ueberauth, Ueberauth.Strategy.Keycloak"

      true ->
        raise "Config :ueberauth, Ueberauth.Strategy.Keycloak is not a keyword list, as expected"
    end
  end

  defp to_keycloak_user(attrs) do
    %{
      "email" => attrs.email,
      "firstName" => attrs.first_name,
      "lastName" => attrs.last_name
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
