json.data do
  json.partial! "api/v1/conversations/conversation", conversation: @conversation
  json.messages @messages do |message|
    json.partial! "api/v1/messages/message", message: message
  end
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
  json.next_before @next_before
  json.newest_first true
end
