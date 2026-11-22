json.data @reviews do |review|
  json.id review.id
  json.rating review.rating
  json.body review.body
  json.seller_reply review.seller_reply_visible? ? review.seller_reply : nil
  json.published review.published?
  json.created_at review.created_at.iso8601
  json.reviewer do
    json.id review.reviewer_id
    json.username review.reviewer.username
    json.display_name review.reviewer.display_name
    json.avatar_url api_avatar_url(review.reviewer)
  end
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
  json.rating_avg @store.rating_avg.to_f
  json.reviews_count @store.reviews_count
end
