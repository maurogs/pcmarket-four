module Admin
  # Writer for the admin listing edit form. Handles virtual money fields,
  # whitelisted labels/tags, effective spec keys and the game FPS JSON editor.
  class ListingUpdate
    ATTRIBUTES = %i[
      title description category_id brand model_name_text condition quantity
      country_code region_id city postal_code shipping_available local_pickup
      free_shipping ships_within_days accepts_offers featured_until
      performance_score status original_price_cents price_cents
    ].freeze
    MONEY_ATTRIBUTES = %i[price original_price shipping_price].freeze

    attr_reader :listing, :errors

    def initialize(listing, params)
      @listing = listing
      @params = params.to_h.with_indifferent_access
    end

    def call
      listing.assign_attributes(scalar_attributes)
      assign_money_attributes
      assign_labels
      assign_specs
      assign_game_fps
      listing.save
    rescue JSON::ParserError
      listing.errors.add(:game_fps, :invalid)
      false
    end

    private

    attr_reader :params

    def scalar_attributes
      attributes = params.slice(*ATTRIBUTES)
      attributes[:tags] = Array(params[:tags]).map(&:to_s) & Listing::TAGS if params.key?(:tags)
      attributes
    end

    def assign_money_attributes
      listing.price = params[:price] if params.key?(:price)
      listing.original_price = params[:original_price] if params.key?(:original_price)
      listing.shipping_price = params[:shipping_price] if params.key?(:shipping_price)
    end

    def assign_labels
      return unless params.key?(:labels)

      listing.labels = Array(params[:labels]).map(&:to_s) & Listing::LABELS
    end

    def assign_specs
      return unless params.key?(:specs)

      allowed = listing.category.effective_filters.map(&:key)
      listing.specs = params[:specs].to_h
                            .slice(*allowed)
                            .transform_values { |value| value.is_a?(Array) ? value.map(&:to_s) : value.to_s }
                            .reject { |_key, value| value.blank? }
    end

    def assign_game_fps
      return unless params.key?(:game_fps_json)

      raw = params[:game_fps_json].to_s.strip
      parsed = raw.blank? ? {} : JSON.parse(raw)
      raise JSON::ParserError, "not an object" unless parsed.is_a?(Hash)

      listing.game_fps = parsed
    end
  end
end
