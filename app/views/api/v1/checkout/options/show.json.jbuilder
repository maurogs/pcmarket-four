json.data do
  json.payment_methods @availability.options.map { |method|
    {
      key: method,
      name: I18n.t("checkout.payment.methods.#{method}", default: method.humanize)
    }
  }
  json.groups @summary.groups do |group|
    shipping_items = group.available_items.select { |item| item.listing.shipping_available? }
    delivery_options = []
    delivery_options << "shipping" if shipping_items.any?
    delivery_options << "local_pickup" if group.available_items.any? { |item| item.listing.local_pickup? }
    delivery_options << "local_pickup" if delivery_options.empty?

    json.seller_id group.seller.id
    json.store_id group.store&.id
    json.store_name group.store_name
    json.pickup_only group.pickup_only?
    json.item_count group.item_count
    json.subtotal api_money(group.subtotal_cents)
    json.shipping api_money(group.shipping_cents)
    json.delivery_options delivery_options.map { |option|
      {
        key: option,
        name: I18n.t("checkout.delivery.#{option}", default: option.humanize)
      }
    }
  end
  json.address do
    json.countries Country.enabled.order(:code) do |country|
      json.code country.code
      json.name country.name
      json.regions country.regions.sort_by(&:name) do |region|
        json.id region.id
        json.name region.name
      end
    end
    if current_user
      json.saved_addresses current_user.addresses.includes(:region).ordered do |address|
        json.id address.id
        json.full_name address.full_name
        json.line1 address.line1
        json.line2 address.line2
        json.city address.city
        json.postal_code address.postal_code
        json.region_id address.region_id
        json.country_code address.country_code
        json.phone address.phone
        json.default address.default?
      end
    else
      json.saved_addresses []
    end
  end
  json.legal do
    json.terms_required true
    json.withdrawal_acknowledgement_required true
  end
end
json.meta do
  json.checkout_token @checkout_token
end
