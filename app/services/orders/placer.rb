# Places the orders behind a cart checkout: one Order per store (a
# multi-seller cart fans out, all orders sharing a checkout_group uuid),
# with listing/price snapshots, per-store totals, the platform commission
# snapshot and the stock decrement — all inside ONE transaction with the
# purchased listings locked FOR UPDATE (ordered by id to avoid deadlocks).
#
# The purchased listings are locked FOR UPDATE (ordered by id to avoid
# deadlocks) before availability is checked, and the cart is refreshed
# against them: anything that went invisible, changed price or lost stock
# since the cart was viewed aborts the whole placement with translated
# errors so the buyer can review the cart (nothing is written).
#
#   Orders::Placer.call(cart:, buyer:, email:, shipping_address:,
#                       shipping_method:, payment_method:, discount_code: nil)
#     → Result(orders, errors, checkout_group)
#
# discount_code is accepted but ignored for now (TODO Phase 4 step 7:
# discount codes — discount_cents stays 0).
module Orders
  class Placer
    Result = Struct.new(:orders, :errors, :checkout_group, keyword_init: true) do
      def success?
        errors.empty?
      end
    end

    # shipping_method values accepted on orders (the Listing enum values are
    # per-listing logistics; on the order they collapse into these two).
    SHIPPING_METHODS = Order::SHIPPING_METHODS
    PAYMENT_METHODS = Order::PAYMENT_METHODS

    # Failures raise this to roll back silently and return the Result
    # (returning from inside `transaction do` would COMMIT, and
    # ActiveRecord::Rollback itself is swallowed by the transaction).
    class Rollback < ActiveRecord::Rollback
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(cart:, buyer:, email:, shipping_address:, shipping_method:,
                   payment_method:, discount_code: nil)
      @cart = cart
      @buyer = buyer
      @email = email.presence || buyer&.email
      @shipping_address = address_snapshot(shipping_address)
      @shipping_method = shipping_method.to_s
      @payment_method = payment_method.to_s
      # TODO Phase 4 step 7 — discount codes land there; accepted, not applied.
      @discount_code = discount_code
      @errors = []
    end

    def call
      checkout_group = SecureRandom.uuid
      orders = []

      ActiveRecord::Base.transaction do
        abort! unless input_valid?

        cart.reload
        if cart.cart_items.empty?
          @errors << I18n.t("orders.placer.errors.empty_cart")
          abort!
        end
        items = cart.cart_items.to_a

        # Lock first, then check: the FOR UPDATE read serialises concurrent
        # checkouts on the same listings, so the stock/visibility checks and
        # the decrement below happen against stable rows.
        listings = lock_listings(items)
        abort! unless listings
        abort! unless stock_available?(items, listings)

        # Sync price/stock drift into the snapshot; any notice means the
        # cart changed since the buyer last saw it, so nothing is placed.
        if cart.refresh!.any?
          @errors << I18n.t("orders.placer.errors.items_changed")
          abort!
        end

        orders = create_orders(items, listings, checkout_group)
        clear_cart(items)
      end

      Result.new(orders: orders, errors: @errors, checkout_group: checkout_group)
    end

    private

    attr_reader :cart, :buyer, :email, :shipping_address, :shipping_method, :payment_method

    # Returning from inside `transaction do` would COMMIT, so failures raise
    # a Rollback subclass instead (silently rolls back, call returns Result).
    def abort!
      raise Rollback
    end

    def input_valid?
      unless PAYMENT_METHODS.include?(payment_method)
        @errors << I18n.t("orders.placer.errors.invalid_payment_method")
      end
      unless SHIPPING_METHODS.include?(shipping_method)
        @errors << I18n.t("orders.placer.errors.invalid_shipping_method")
      end
      if shipping_address.blank?
        @errors << I18n.t("orders.placer.errors.missing_shipping_address")
      end
      if email.blank?
        @errors << I18n.t("orders.placer.errors.missing_email")
      end
      @errors.empty?
    end

    # FOR UPDATE on the purchased listings, always locked in id order so two
    # concurrent checkouts sharing a listing can never deadlock. A listing
    # that vanished between the cart read and the lock means the cart row was
    # cascade-destroyed — treat it as a changed cart.
    def lock_listings(items)
      ids = items.map(&:listing_id).sort
      locked = Listing.where(id: ids).order(:id).lock.to_a.index_by(&:id)
      if locked.size != ids.uniq.size
        @errors << I18n.t("orders.placer.errors.items_changed")
        return nil
      end
      locked
    end

    def stock_available?(items, listings)
      ok = true
      needed = Hash.new(0)
      items.each { |item| needed[item.listing_id] += item.quantity }

      needed.each do |listing_id, quantity|
        listing = listings[listing_id]
        next if listing.visible_to_public? && listing.quantity >= quantity

        @errors << I18n.t("orders.placer.errors.listing_unavailable", title: listing.title)
        ok = false
      end
      ok
    end

    def create_orders(items, listings, checkout_group)
      items.group_by { |item| listings.fetch(item.listing_id).store_id }
           .sort_by { |store_id, _| store_id }
           .map do |store_id, store_items|
        create_order(store_id, store_items, listings, checkout_group)
      end
    end

    def create_order(store_id, store_items, listings, checkout_group)
      subtotal = store_items.sum { |item| item.quantity * item.unit_price_cents }
      shipping = store_items.sum { |item| shipping_cents_for(listings.fetch(item.listing_id)) }
      percent = commission_percent
      commission = (subtotal * BigDecimal(percent.to_s) / 100).round

      order = Order.new(
        store_id: store_id,
        buyer: buyer,
        buyer_email: email,
        payment_method: payment_method,
        shipping_method: shipping_method,
        shipping_address: shipping_address,
        checkout_group: checkout_group,
        locale: I18n.locale.to_s,
        currency: listings.fetch(store_items.first.listing_id).currency,
        subtotal_cents: subtotal,
        shipping_cents: shipping,
        discount_cents: 0,
        total_cents: subtotal + shipping,
        commission_cents: commission,
        commission_percent: percent,
        placed_at: Time.current
      )
      order.save!

      store_items.each do |item|
        listing = listings.fetch(item.listing_id)
        sold = take_stock(listing, item.quantity)
        order.order_items.create!(
          listing: listing,
          title: listing.title,
          unit_price_cents: item.unit_price_cents,
          quantity: item.quantity,
          line_total_cents: item.quantity * item.unit_price_cents,
          condition: listing.condition,
          image_blob_signed_id: listing.ordered_images.first&.signed_id,
          sold_listing: sold
        )
      end
      order
    end

    # Pickup is free; otherwise one fee per distinct listing (sellers
    # combine parcels), free-shipping listings costing nothing.
    def shipping_cents_for(listing)
      return 0 if shipping_method == "pickup"
      return 0 if listing.free_shipping

      listing.shipping_price_cents
    end

    def commission_percent
      return 0 unless AppSettings.enabled?("commission_enabled")

      AppSettings.get("commission_percent", 0).to_d
    end

    # Reserved stock: decrement, or mark the listing sold when the purchase
    # takes the last units (mirrors Listing#record_offline_sale! for n
    # units). Returns whether the listing went sold by this order.
    def take_stock(listing, quantity)
      if listing.quantity > quantity
        listing.update!(quantity: listing.quantity - quantity)
        false
      else
        listing.mark_sold!
        true
      end
    end

    def clear_cart(items)
      cart.cart_items.where(id: items.map(&:id)).delete_all
    end

    # Address snapshots are frozen into the order (jsonb): an Address record
    # is reduced to its delivery fields, a Hash is kept as-is.
    def address_snapshot(address)
      return address.to_h if address.is_a?(Hash)
      return nil if address.nil?

      {
        "label" => address.label,
        "first_name" => address.first_name,
        "last_name" => address.last_name,
        "company" => address.company,
        "street_line1" => address.street_line1,
        "street_line2" => address.street_line2,
        "postal_code" => address.postal_code,
        "city" => address.city,
        "province" => address.province,
        "country" => address.country.code,
        "phone" => address.phone
      }
    end
  end
end
