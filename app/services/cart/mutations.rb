module Cart
  # Shared cart mutation rules for the web Turbo controller and the JSON API:
  # own listings and vacation stores are rejected, and quantities are capped by
  # the listing stock.
  module Mutations
    MAX_QUANTITY = 10

    class Error < StandardError
      attr_reader :message_key

      def initialize(message_key)
        @message_key = message_key
        super(message_key)
      end
    end

    module_function

    def add(scope:, listing:, quantity:, user: nil, cart_token: nil)
      raise Error, "own_listing" if user.present? && listing.user_id == user.id
      raise Error, "vacation" if listing.store&.on_vacation?

      requested = quantity.to_i
      requested = 1 if requested < 1
      requested = [ requested, MAX_QUANTITY ].min

      item = scope.find_or_initialize_by(listing_id: listing.id)
      item.user = user if user.present?
      item.cart_token = cart_token if user.blank? && item.new_record?
      item.quantity = cap(item.quantity.to_i + requested, listing)
      item.save!
      item
    end

    def update(item:, quantity:)
      quantity = quantity.to_i
      raise Error, "unavailable" unless quantity.positive?

      item.update!(quantity: cap(quantity, item.listing))
      item
    end

    def cap(quantity, listing)
      [ [ quantity, listing.quantity.to_i ].min, 1 ].max
    end
  end
end
