json.data do
  json.partial! "api/v1/shared/user", user: @user
end
json.meta({})
