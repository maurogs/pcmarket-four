json.data do
  json.id @favorite.id
  json.listing_id @favorite.listing_id
  json.created_at @favorite.created_at.iso8601
  json.favorites_count Favorite.where(listing_id: @favorite.listing_id).count
end
json.meta({})
