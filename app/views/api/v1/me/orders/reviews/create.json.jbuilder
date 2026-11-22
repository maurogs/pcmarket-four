json.data do
  json.id @review.id
  json.order_id @review.order_id
  json.store_id @review.store_id
  json.rating @review.rating
  json.body @review.body
  json.published @review.published?
  json.created_at @review.created_at.iso8601
end
json.meta({})
