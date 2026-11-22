json.data do
  json.following follow.present?
  json.follow_id follow&.id
  json.store_slug @store.slug
  json.followers_count @store.followers_count
end
json.meta({})
