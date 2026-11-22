json.data @conversations do |conversation|
  json.partial! "api/v1/conversations/conversation", conversation: conversation
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
  json.tab @tab
  json.unread_total Conversation.unread_total_for(current_user)
end
