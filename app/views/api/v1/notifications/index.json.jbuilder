json.data @notifications do |notification|
  json.partial! "api/v1/notifications/notification", notification: notification
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
  json.unread_count current_user.notifications.unread.count
end
