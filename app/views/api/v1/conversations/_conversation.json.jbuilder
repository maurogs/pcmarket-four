json.id conversation.id
json.listing do
  if conversation.listing
    json.id conversation.listing_id
    json.slug conversation.listing.slug
    json.title conversation.listing.title
    json.price api_money(conversation.listing.price_cents, conversation.listing.currency)
    json.image_url(api_listing_images(conversation.listing).first)
  end
end
json.buyer do
  json.id conversation.buyer_id
  json.username conversation.buyer.username
  json.display_name conversation.buyer.display_name
end
json.seller do
  json.id conversation.seller_id
  json.username conversation.seller.username
  json.display_name conversation.seller.display_name
end
json.other_party do
  other = conversation.other_party(current_user)
  json.id other.id
  json.username other.username
  json.display_name other.display_name
end
json.last_message_at conversation.last_message_at&.iso8601
json.unread_count conversation.unread_count_for(current_user)
json.archived conversation.archived_for?(current_user)
last_message = conversation.messages.max_by { |message| [ message.created_at, message.id ] }
json.last_message do
  if last_message
    json.id last_message.id
    json.body last_message.body
    json.kind last_message.kind
    json.sender_id last_message.sender_id
    json.created_at last_message.created_at.iso8601
  end
end
