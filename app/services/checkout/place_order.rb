module Checkout
  # Creates one order per seller inside a single transaction. Listings are
  # locked FOR UPDATE before stock is checked so two buyers cannot oversell the
  # same unit. checkout_token makes a double submit return the original orders.
  class PlaceOrder
    class Error < StandardError
      attr_reader :message_key

      def initialize(message_key, message = nil)
        @message_key = message_key
        super(message || message_key)
      end
    end

    def initialize(form:, summary:)
      @form = form
      @summary = summary
    end

    def call
      validate_input!
      existing = existing_orders
      return existing if existing.any?

      orders = Order.transaction do
        locked = lock_listings
        revalidate!(locked)
        created = create_orders(locked)
        decrement_stock!(locked)
        save_address!
        clear_cart!
        created
      end

      enqueue_notifications(orders)
      orders
    rescue ActiveRecord::RecordNotUnique
      existing_orders.presence || raise
    end

    private

    attr_reader :form, :summary

    def validate_input!
      raise Error, "empty_cart" if summary.groups.empty?
      raise Error, "unavailable_items" unless summary.available?
      raise Error, "unavailable_items" unless summary.groups.all? { |group| group.available_items.any? }
    end

    def existing_orders
      return [] if form.checkout_token.blank?

      scoped = Order.where(checkout_token: form.checkout_token)
      scoped = scoped.where(buyer_id: form.user.id) if form.user.present?
      scoped.order(:id).to_a
    end

    def purchased_items
      @purchased_items ||= summary.available_items
    end

    def lock_listings
      Listing.where(id: purchased_items.map { |item| item.listing.id })
             .order(:id)
             .lock("FOR UPDATE")
             .to_a
             .index_by(&:id)
    end

    def revalidate!(locked)
      purchased_items.each do |item|
        listing = locked[item.listing_id]
        unless listing && listing.visible? && listing.quantity.to_i >= item.quantity
          raise Error, "stock_changed"
        end
      end
    end

    def create_orders(locked)
      summary.groups.filter_map do |group|
        items = group.available_items
        next if items.empty?

        fulfilment = form.delivery_for(group)
        order = Order.new(
          buyer: form.user,
          seller: group.seller,
          store: group.store,
          status: :pending_payment,
          fulfilment: fulfilment,
          buyer_email: form.email,
          payment_method: form.payment_method,
          payment_provider: form.payment_method,
          locale: I18n.locale.to_s,
          checkout_token: form.checkout_token,
          terms_accepted_at: Time.current,
          shipping_cents: fulfilment == "shipping" ? shipping_for(items, locked) : 0
        )
        assign_shipping_address(order) if fulfilment == "shipping"
        order.save!

        items.each do |item|
          listing = locked[item.listing_id]
          order.order_items.create!(
            listing: listing,
            title_snapshot: listing.title,
            price_cents: item.unit_price_cents,
            quantity: item.quantity
          )
        end

        order.compute_totals!
        order
      end
    end

    def shipping_for(items, locked)
      listings = items.map { |item| locked[item.listing_id] }
      return 0 if listings.any? { |listing| !listing.shipping_available? }

      listings.sum do |listing|
        listing.free_shipping? ? 0 : listing.shipping_price_cents.to_i
      end
    end

    def assign_shipping_address(order)
      address = form.shipping_address
      order.ship_name = address[:full_name]
      order.ship_line1 = address[:line1]
      order.ship_line2 = address[:line2]
      order.ship_city = address[:city]
      order.ship_postal_code = address[:postal_code]
      order.ship_region = address[:region_name]
      order.ship_country_code = address[:country_code]
      order.ship_phone = address[:phone]
    end

    def decrement_stock!(locked)
      purchased_items.each do |item|
        listing = locked[item.listing_id]
        remaining = listing.quantity.to_i - item.quantity
        listing.update_columns(
          quantity: remaining,
          status: remaining.zero? ? Listing.statuses[:sold] : listing.status,
          updated_at: Time.current
        )
      end
    end

    def save_address!
      return unless form.save_address?

      address = form.shipping_address
      form.user.addresses.create!(
        full_name: address[:full_name],
        line1: address[:line1],
        line2: address[:line2],
        city: address[:city],
        postal_code: address[:postal_code],
        region_id: address[:region_id],
        country_code: address[:country_code],
        phone: address[:phone]
      )
    end

    def clear_cart!
      CartItem.where(id: purchased_items.map { |item| item.cart_item.id }).delete_all
    end

    def enqueue_notifications(orders)
      orders.each do |order|
        OrderMailer.placed_buyer(order).deliver_later
        if order.seller.notify_by_email?("email_order_updates")
          OrderMailer.placed_seller(order).deliver_later
        end
      end
    end
  end
end
