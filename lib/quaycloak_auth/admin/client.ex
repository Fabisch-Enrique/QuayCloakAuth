defmodule QuaycloakAuth.Admin.Client do
  use VCUtils.HTTPClient

  require Logger

  @headers [{"Content-Type", "application/x-www-form-urlencoded"}]

  def config(),
    do:
      :ueberauth
      |> Application.get_env(QuaycloakAuth)
      |> check_config_keys_exist(:client_id)
      |> check_config_keys_exist(:client_secret)

  @spec config(atom()) :: any()
  def config(key), do: config() |> Keyword.get(key)

  def get_token() do
    url = config(:token_url)

    body =
      URI.encode_query(%{
        client_id: config(:client_id),
        grant_type: "client_credentials",
        client_secret: config(:client_secret)
      })

    with {:ok, %{status: 200, body: body}} <- request(:post, url, body, @headers) do
      {:ok, body}
    end
  end

  def introspect_token(token) do
    url = config(:introspect_url)

    body =
      URI.encode_query(%{
        token: token,
        client_id: config(:client_id),
        client_secret: config(:client_secret)
      })

    with {:ok, %{status: 200, body: body}} <- request(:post, url, body, @headers) do
      {:ok, body}
    end
  end

  def logout(user_id) do
    url = "#{config(:base_url)}/admin/realms/#{config(:realm)}/users/#{user_id}/logout"

    with {:ok, body} <- get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"}
         ],
         {:error, _error} <- request(:post, url, "", headers) do
      :ok
    end
  end

  def create_client(client_id) do
    url = config(:base_url) <> "/admin/realms/" <> config(:realm) <> "/clients"

    payload = %{
      "enabled" => true,
      "clientId" => client_id,
      "publicClient" => false,
      "protocol" => "openid-connect",
      "standardFlowEnabled" => false,
      "serviceAccountsEnabled" => true,
      "directAccessGrantsEnabled" => false
    }

    with {:ok, body} <- get_token(),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"},
           {"Content-Type", "application/json"}
         ],
         {:ok, %{status: status} = resp} when status in [201, 204] <-
           request(:post, url, Jason.encode!(payload), headers),
         {:ok, body} <- extract_created_client_internal_id(resp, client_id, headers),
         {:ok, body} <- fetch_client_secret(hd(Enum.map(body.body, & &1.id)), headers) do
      {:ok, %{client_id: client_id, client_secret: body.body.value}}
    end
  end

  # --------------------- Private/Helper Functions -------------------------- #

  defp fetch_client_secret(internal_id, headers) do
    url =
      config(:base_url) <>
        "/admin/realms/" <> config(:realm) <> "/clients/" <> internal_id <> "/client-secret"

    with {:ok, %{status: 200, body: %{"value" => secret}}} <- request(:get, url, "", headers) do
      {:ok, secret}
    end
  end

  defp extract_created_client_internal_id(_resp, client_id, headers) do
    url =
      config(:base_url) <>
        "/admin/realms/" <> config(:realm) <> "/clients?clientId=" <> URI.encode(client_id)

    with {:ok, %{status: 200, body: [%{"id" => internal_id} | _]}} <-
           request(:get, url, "", headers) do
      {:ok, internal_id}
    else
      {:ok, %{status: 200, body: []}} -> {:error, :client_not_found_after_create}
      other -> other
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
end
