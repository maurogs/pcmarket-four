json.id listing.id
json.slug listing.slug
json.title listing.title
json.description listing.description
json.price api_money(listing.price_cents, listing.currency)
json.original_price(listing.original_price_cents ? api_money(listing.original_price_cents, listing.currency) : nil)
json.currency listing.currency
json.condition listing.condition
json.condition_name api_condition_name(listing.condition)
json.status listing.status
json.quantity listing.quantity
json.brand listing.brand
json.model listing.model_name_text
json.specs listing.specs
json.labels listing.labels.map { |key| { key: key, name: api_label_name(key) } }
json.tags listing.tags.map { |key| { key: key, name: api_tag_name(key) } }
json.location listing.location
json.city listing.city
json.postal_code listing.postal_code
json.country_code listing.country_code
json.region_id listing.region_id
json.shipping do
  json.available listing.shipping_available
  json.free listing.free_shipping?
  json.price_cents listing.shipping_price_cents
  json.ships_within_days listing.ships_within_days
end
json.local_pickup listing.local_pickup
json.accepts_offers listing.accepts_offers
json.featured listing.featured?
json.views_count listing.views_count
json.favorites_count listing.favorites_count
json.published_at listing.published_at&.iso8601
json.created_at listing.created_at.iso8601
json.updated_at listing.updated_at.iso8601
json.images api_listing_images(listing)

json.category do
  json.id listing.category_id
  json.slug listing.category&.slug
  json.name listing.category&.name
end

json.seller do
  if listing.user
    json.id listing.user_id
    json.username listing.user.username
    json.display_name listing.user.display_name
    json.avatar_url api_avatar_url(listing.user)
  end
end

json.store do
  if listing.store
    json.id listing.store_id
    json.slug listing.store.slug
    json.name listing.store.name
    json.verified listing.store.verified?
    json.professional listing.store.professional?
    json.rating_avg listing.store.rating_avg.to_f
    json.reviews_count listing.store.reviews_count
  end
end
