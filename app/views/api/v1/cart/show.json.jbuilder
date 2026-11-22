json.data do
  json.item_count @summary.item_count
  json.subtotal api_money(@summary.subtotal_cents)
  json.shipping api_money(@summary.shipping_cents)
  json.total api_money(@summary.total_cents)
  json.all_pickup @summary.all_pickup?
  json.groups @summary.groups do |group|
    json.seller_id group.seller.id
    json.seller_name group.seller.display_name
    json.store_id group.store&.id
    json.store_name group.store_name
    json.store_slug group.store&.slug
    json.pickup_only group.pickup_only?
    json.free_shipping group.free_shipping?
    json.shipping api_money(group.shipping_cents)
    json.subtotal api_money(group.subtotal_cents)
    json.items group.items do |item|
      json.id item.cart_item.id
      json.quantity item.quantity
      json.unit_price api_money(item.unit_price_cents, item.listing.currency)
      json.subtotal api_money(item.subtotal_cents, item.listing.currency)
      json.available item.available?
      json.warning_code item.warning_code
      json.warning do
        json.message item.warning_key ? t(item.warning_key) : nil
      end
      json.listing do
        json.partial! "api/v1/listings/listing", listing: item.listing
      end
    end
  end
  json.warnings @summary.warnings do |warning|
    json.code warning.code
    json.listing_id warning.listing_id
    json.message t(warning.message_key)
  end
end
json.meta({})
