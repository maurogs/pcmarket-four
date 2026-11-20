# Card/detail building blocks for listings: lazy webp pictures, spec chips
# and location text. Queries run at most once per filter key per request and
# are memoized in instance variables, so a whole grid of cards shares them.
module ListingsHelper
  # Responsive webp picture with intrinsic dimensions (no layout shift), or
  # a placeholder when the listing has no images. Uses the seller's gallery
  # order, so the cover is the first image in image_order.
  def listing_picture(listing, variant: :card, css: "h-full w-full object-cover")
    image = listing.ordered_images.first
    return listing_image_placeholder if image.nil?

    metadata = image.blob.metadata || {}

    tag.picture do
      safe_join(
        [
          tag.source(type: "image/webp", srcset: url_for(image.variant(**Listing::IMAGE_VARIANTS.fetch(variant), format: Listing::IMAGE_FORMAT))),
          image_tag(url_for(image), alt: listing.title, loading: "lazy", decoding: "async",
                    width: metadata["width"] || 800, height: metadata["height"] || 800, class: css)
        ]
      )
    end
  end

  def listing_image_placeholder
    tag.div(class: "flex h-full w-full items-center justify-center bg-cream-100 text-primary-300 dark:bg-cream-surface dark:text-primary-700") do
      icon("image", class: "h-10 w-10")
    end
  end

  # Up to `limit` spec values (e.g. "NVIDIA", "12 GB"), ordered by the
  # filter definitions' position — shown as chips on the card.
  def spec_chip_labels(listing, limit: 4)
    return [] if listing.specs.blank?

    chips = []
    spec_chip_definitions(listing.specs.keys).each do |definition|
      spec_values(listing, definition.key)
        .sort_by { |value| value_option(definition.key, value)[:position] }
        .each { |value| chips << value_option(definition.key, value)[:label] }
    end
    chips.first(limit)
  end

  # Spec table rows grouped by FilterDefinition group:
  # [ [group_label, [ [definition_label, "NVIDIA, 12 GB"], … ] ], … ]
  def spec_grouped(listing)
    return [] if listing.specs.blank?

    spec_chip_definitions(listing.specs.keys).each_with_object([]) do |definition, groups|
      options = spec_values(listing, definition.key).map { |value| value_option(definition.key, value) }
      next if options.empty?

      group_label = definition.group
      entry = groups.find { |label, _| label == group_label }
      entry ||= groups.tap { |g| g << [ group_label, [] ] }.last
      entry[1] << [ definition.label, options.sort_by { |option| option[:position] }.map { |option| option[:label] }.join(", ") ]
    end
  end

  # Shipping fee shown next to the shipping label (paid listings only).
  def listing_display_shipping_price(listing)
    number_to_currency(listing.shipping_price_cents.to_i / 100.0, unit: "€")
  end

  # "Madrid, Madrid" style location (province + city).
  def listing_location(listing)
    parts = []
    if listing.province.present?
      parts << t("spanish_provinces.#{listing.province}", default: listing.province.humanize)
    end
    parts << listing.city if listing.city.present?
    parts.join(", ").presence
  end

  private
    # FilterDefinitions for the given spec keys, ordered by position, cached
    # per request in @spec_definitions_by_key.
    def spec_chip_definitions(keys)
      keys.map { |key| spec_definition(key.to_s) }.compact.uniq
        .sort_by { |definition| [ definition.position.to_i, definition.id ] }
    end

    def spec_definition(key)
      spec_definitions_by_key[key]
    end

    def spec_definitions_by_key
      @spec_definitions_by_key ||= FilterDefinition.includes(filter_options: []).index_by(&:key)
    end

    # Raw spec values stored for a key on this listing.
    def spec_values(listing, key)
      Array(listing.specs[key])
    end

    # { label:, position: } for one spec value; falls back to a humanized
    # value when the catalog has no matching FilterOption.
    def value_option(key, value)
      options = spec_definitions_by_key[key]&.filter_options&.select(&:active?) || []
      option = options.find { |candidate| candidate.value == value }
      { label: option&.label || value.to_s.humanize, position: option&.position || 999 }
    end
end
