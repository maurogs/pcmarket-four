json.data do
  json.token @token.plain_token
  json.token_type "Bearer"
  json.expires_at @token.expires_at&.iso8601
  json.user do
    json.partial! "api/v1/shared/user", user: @user
  end
end
json.meta do
  json.message t("api.messages.session_created")
end
