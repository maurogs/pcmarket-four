json.id order.id
json.number order.number
json.status order.status
json.fulfilment order.fulfilment
json.currency order.currency
json.subtotal api_money(order.subtotal_cents, order.currency)
json.shipping api_money(order.shipping_cents, order.currency)
json.commission api_money(order.commission_cents, order.currency)
json.total api_money(order.total_cents, order.currency)
json.payment_method order.payment_method
json.payment_provider order.payment_provider
json.payment_reference order.payment_reference
json.buyer_email order.buyer_email
json.locale order.locale
json.tracking_number order.tracking_number
json.carrier order.carrier
json.tracking_url(order.tracking_url)
json.paid_at order.paid_at&.iso8601
json.shipped_at order.shipped_at&.iso8601
json.delivered_at order.delivered_at&.iso8601
json.completed_at order.completed_at&.iso8601
json.cancelled_at order.cancelled_at&.iso8601
json.disputed_at order.disputed_at&.iso8601
json.refunded_at order.refunded_at&.iso8601
json.created_at order.created_at.iso8601
json.updated_at order.updated_at.iso8601
json.cancellable order.cancellable?
json.inspection_window_open order.inspection_window_open?
json.reviewed order.review.present?

json.store do
  if order.store
    json.id order.store_id
    json.slug order.store.slug
    json.name order.store.name
  end
end

json.seller do
  json.id order.seller_id
  json.username order.seller.username
  json.display_name order.seller.display_name
end

json.buyer do
  if order.buyer
    json.id order.buyer_id
    json.username order.buyer.username
    json.display_name order.buyer.display_name
  end
end

json.shipping_address do
  json.full_name order.ship_name
  json.line1 order.ship_line1
  json.line2 order.ship_line2
  json.city order.ship_city
  json.postal_code order.ship_postal_code
  json.region order.ship_region
  json.country_code order.ship_country_code
  json.phone order.ship_phone
end

json.items order.order_items do |item|
  json.id item.id
  json.listing_id item.listing_id
  json.listing_slug item.listing&.slug
  json.title item.title_snapshot
  json.price api_money(item.price_cents, order.currency)
  json.quantity item.quantity
  json.subtotal api_money(item.subtotal_cents, order.currency)
  json.image_url(item.listing ? api_listing_images(item.listing).first : nil)
end

json.timeline order.order_events.sort_by(&:created_at) do |event|
  json.kind event.kind
  json.data event.data
  json.actor_id event.actor_id
  json.created_at event.created_at.iso8601
end
