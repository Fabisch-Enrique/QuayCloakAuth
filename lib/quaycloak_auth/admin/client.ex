defmodule QuaycloakAuth.Admin.Client do
  use VCUtils.HTTPClient

  require Logger

  @headers [{"Content-Type", "application/x-www-form-urlencoded"}]

  def config(app_name), do: QuaycloakAuth.config(app_name)

  def config(app_name, key),
    do: config(app_name) |> check_config_keys_exist(app_name, key) |> Keyword.get(key)

  def get_token(app_name) do
    url = config(app_name, :token_url)

    body =
      URI.encode_query(%{
        client_id: config(app_name, :client_id),
        grant_type: "client_credentials",
        client_secret: config(app_name, :client_secret)
      })

    with {:ok, %{status: 200, body: body}} <- request(:post, url, body, @headers) do
      {:ok, body}
    end
  end

  def introspect_token(app_name, token) do
    url = config(:introspect_url)

    body =
      URI.encode_query(%{
        token: token,
        client_id: config(app_name, :client_id),
        client_secret: config(app_name, :client_secret)
      })

    with {:ok, %{status: 200, body: body}} <- request(:post, url, body, @headers) do
      {:ok, body}
    end
  end

  def create_client(app_name, client_id) do
    url =
      config(app_name, :base_url) <> "/admin/realms/" <> config(app_name, :realm) <> "/clients"

    payload = %{
      "enabled" => true,
      "clientId" => client_id,
      "publicClient" => false,
      "protocol" => "openid-connect",
      "standardFlowEnabled" => false,
      "serviceAccountsEnabled" => true,
      "directAccessGrantsEnabled" => false
    }

    with {:ok, body} <- get_token(app_name),
         headers = [
           {"Authorization", "Bearer #{body.access_token}"},
           {"Content-Type", "application/json"}
         ],
         {:ok, %{status: status} = resp} when status in [201, 204] <-
           request(:post, url, Jason.encode!(payload), headers),
         {:ok, body} <- extract_created_client_internal_id(resp, app_name, client_id, headers),
         {:ok, body} <- fetch_client_secret(app_name, hd(Enum.map(body.body, & &1.id)), headers) do
      {:ok, %{client_id: client_id, client_secret: body.body.value}}
    end
  end

  # -------------------------------- Private/Helper Functions ------------------------------------ #

  defp fetch_client_secret(app_name, internal_id, headers) do
    url =
      config(app_name, :base_url) <>
        "/admin/realms/" <>
        config(app_name, :realm) <> "/clients/" <> internal_id <> "/client-secret"

    with {:ok, %{status: 200, body: %{"value" => secret}}} <- request(:get, url, "", headers) do
      {:ok, secret}
    end
  end

  defp extract_created_client_internal_id(_resp, app_name, client_id, headers) do
    url =
      config(app_name, :base_url) <>
        "/admin/realms/" <>
        config(app_name, :realm) <> "/clients?clientId=" <> URI.encode(client_id)

    with {:ok, %{status: 200, body: [%{"id" => internal_id} | _]}} <-
           request(:get, url, "", headers) do
      {:ok, internal_id}
    else
      {:ok, %{status: 200, body: []}} -> {:error, :client_not_found_after_create}
      other -> other
    end
  end

  defp check_config_keys_exist(config, app_name, key) do
    cond do
      is_list(config) ->
        if Keyword.has_key?(config, key),
          do: config,
          else:
            raise(
              "#{inspect(key)} missing from config :app_name, QuaycloakAuth for APP:: #{inspect(app_name)}"
            )

      true ->
        raise "Config :app_name, QuaycloakAuth for APP:: #{inspect(app_name)} is not a keyword list, as expected"
    end
  end
end
