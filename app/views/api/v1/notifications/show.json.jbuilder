json.data do
  json.partial! "api/v1/notifications/notification", notification: @notification
end
json.meta({})
