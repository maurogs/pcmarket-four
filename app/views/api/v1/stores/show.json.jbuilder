json.data do
  json.id @store.id
  json.slug @store.slug
  json.name @store.name
  json.description @store.description
  json.store_type @store.store_type
  json.verified @store.verified?
  json.vacation_mode @store.vacation_mode?
  json.vacation_message @store.vacation_message
  json.company_name @store.company_name
  json.rating_avg @store.rating_avg.to_f
  json.reviews_count @store.reviews_count
  json.followers_count @store.followers_count
  json.sales_count @store.sales_count
  json.listings_count @listings_count
  json.return_policy @store.return_policy
  json.shipping_policy @store.shipping_policy
  json.location @store.location
  json.city @store.city
  json.country_code @store.country_code
  json.region_id @store.region_id
  json.created_at @store.created_at.iso8601
  json.logo_url api_store_logo_url(@store)
  json.banner_url api_store_banner_url(@store)
  json.following @follow.present?
  json.follow_id @follow&.id
  json.owner do
    json.id @store.user_id
    json.username @store.user.username
    json.display_name @store.user.display_name
  end
end
json.meta({})
