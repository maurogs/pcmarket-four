json.data do
  json.partial! "api/v1/messages/message", message: @message
end
json.meta({})
