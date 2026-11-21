# Read model for the cart, the header badge and checkout. It never mutates
# cart rows: stock reductions are reported as warnings and quantities are
# clamped in memory so the buyer always sees what can actually be bought.
class CartSummary
  Warning = Struct.new(:code, :listing_id, keyword_init: true) do
    def message_key
      "cart.warnings.#{code}"
    end
  end

  Item = Struct.new(:cart_item, :listing, :quantity, :unit_price_cents,
                    :subtotal_cents, :available, :warning_code, keyword_init: true) do
    def available?
      available
    end

    def warning?
      warning_code.present?
    end

    def warning_key
      warning_code.present? ? "cart.warnings.#{warning_code}" : nil
    end

    def store
      listing.store
    end

    def seller
      listing.user
    end

    def listing_id
      listing.id
    end

    def seller_id
      seller.id
    end
  end

  Group = Struct.new(:seller, :store, :items, :shipping_cents, :subtotal_cents,
                     :pickup_only, keyword_init: true) do
    def available_items
      items.select(&:available?)
    end

    def item_count
      available_items.sum(&:quantity)
    end

    def store_name
      store&.name.presence || seller&.display_name
    end

    def pickup_only?
      pickup_only
    end

    def free_shipping?
      shipping_cents.zero? && !pickup_only
    end
  end

  attr_reader :cart_items, :groups, :warnings

  def self.for(user: nil, token: nil)
    scope = if user.present?
      CartItem.where(user_id: user.id)
    elsif token.present?
      CartItem.where(cart_token: token)
    else
      CartItem.none
    end

    new(scope)
  end

  def initialize(cart_items)
    @cart_items = cart_items
    @groups = build_groups
    @warnings = @groups.flat_map { |group| group.items.select(&:warning?) }
                         .map { |item| Warning.new(code: item.warning_code, listing_id: item.listing.id) }
  end

  def empty?
    cart_items.to_a.empty?
  end

  def items
    groups.flat_map(&:items)
  end

  def available_items
    items.select(&:available?)
  end

  def available?
    available_items.any?
  end

  def item_count
    available_items.sum(&:quantity)
  end

  def subtotal_cents
    groups.sum(&:subtotal_cents)
  end

  def shipping_cents
    groups.sum(&:shipping_cents)
  end

  def total_cents
    subtotal_cents + shipping_cents
  end

  def listing_ids
    items.map { |item| item.listing.id }
  end

  def category_ids
    available_items.map { |item| item.listing.category_id }.uniq
  end

  def pickup_only?
    groups.any?(&:pickup_only)
  end

  def all_pickup?
    groups.any? && groups.all?(&:pickup_only)
  end

  def warnings?
    warnings.any?
  end

  def group_for(seller_id)
    groups.find { |group| group.seller.id == seller_id.to_i }
  end

  private

  def build_groups
    grouped = load_items.group_by { |item| [ item.seller.id, item.store&.id ] }

    grouped.map do |(seller_id, _store_id), items|
      seller = items.first.seller
      store = items.first.store
      available = items.select(&:available?)
      pickup_only = available.any? { |item| !item.listing.shipping_available? }

      Group.new(
        seller: seller,
        store: store,
        items: items,
        pickup_only: pickup_only,
        subtotal_cents: available.sum(&:subtotal_cents),
        shipping_cents: pickup_only ? 0 : available.sum { |item| shipping_for(item.listing) }
      )
    end.sort_by { |group| group.store_name.to_s.downcase }
  end

  def load_items
    records = cart_items.includes(
      listing: [ :store, :user, { images_attachments: :blob } ]
    ).order(created_at: :desc).to_a

    records.filter_map { |cart_item| build_item(cart_item) }
  end

  def build_item(cart_item)
    listing = cart_item.listing
    return nil if listing.blank? || listing.user.blank?

    code = unavailability_code(listing)
    quantity = code ? 0 : [ cart_item.quantity.to_i, listing.quantity.to_i ].min
    code = "quantity_reduced" if code.nil? && quantity < cart_item.quantity.to_i
    code = "unavailable" if code.nil? && quantity < 1

    available = code.nil? || code == "quantity_reduced"

    Item.new(
      cart_item: cart_item,
      listing: listing,
      quantity: quantity,
      unit_price_cents: cart_item.effective_price_cents,
      subtotal_cents: cart_item.effective_price_cents * quantity,
      available: available,
      warning_code: code
    )
  end

  def unavailability_code(listing)
    return "sold" if listing.sold?
    return "vacation" if listing.store&.on_vacation?
    return "unavailable" unless listing.visible?

    nil
  end

  def shipping_for(listing)
    return 0 unless listing.shipping_available?
    return 0 if listing.free_shipping?

    listing.shipping_price_cents.to_i
  end
end
