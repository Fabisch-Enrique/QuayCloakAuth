defmodule QuaycloakAuth.Ueberauth do
  def extract(%{
        uid: uid,
        extra: %Ueberauth.Auth.Extra{raw_info: %{user: raw_user_info} = raw_info},
        info: info
      }) do
    name =
      info.name ||
        (info.first_name && info.last_name && "#{info.first_name} #{info.last_name}") ||
        info.first_name ||
        info.nickname ||
        "Unknown User"

    user_info = %{
      id: uid || raw_user_info["sub"],
      name: name,
      email: info.email
    }

    token = raw_info.token

    raw = %{
      user: raw_info.user,
      token: token.access_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      other_params: token.other_params,
      refresh_token: token.refresh_token
    }

    {:ok, user_info, raw}
  end

  def extract(_), do: {:error, :invalid_auth}
end
