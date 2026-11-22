json.id message.id
json.conversation_id message.conversation_id
json.sender_id message.sender_id
json.kind message.kind
json.body message.body
json.offer_amount_cents message.offer_amount_cents
json.offer_amount(message.offer_amount_cents ? api_money(message.offer_amount_cents) : nil)
json.offer_status message.offer_status
json.offer_expires_at message.offer_expires_at&.iso8601
json.flagged message.flagged?
json.read message.read?
json.read_at message.read_at&.iso8601
json.created_at message.created_at.iso8601
json.sender do
  if message.sender
    json.id message.sender_id
    json.username message.sender.username
    json.display_name message.sender.display_name
  end
end
