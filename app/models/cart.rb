# A shopping cart: one per signed-in user, or a guest cart addressed by its
# token through a signed permanent cookie (see CurrentCart and
# config/initializers/warden_cart_merge.rb, which merges guest carts into
# the user's cart on sign-in).
class Cart < ApplicationRecord
  # Signed permanent cookie holding a guest cart's token.
  COOKIE = "pcmarket_cart".freeze

  # Outcome of #add. :added / :increased / :capped are successes (:capped
  # means the requested quantity hit the listing's stock); :own_listing and
  # :not_available are rejections.
  AddOutcome = Struct.new(:status, :item, keyword_init: true) do
    def success?
      %i[added increased capped].include?(status)
    end
  end

  belongs_to :user, optional: true
  has_many :cart_items, dependent: :destroy

  validates :token, presence: true, uniqueness: true

  before_validation :ensure_token, on: :create

  scope :guest, -> { where(user_id: nil) }

  # Adds `listing` (or raises its quantity), snapshotting the current price.
  # Rejects the user's own listings and anything not publicly visible; the
  # total quantity per listing is capped by the listing's stock.
  def add(listing, quantity: 1)
    return AddOutcome.new(status: :not_available) if listing.nil?
    return AddOutcome.new(status: :not_available) unless listing.visible_to_public?
    return AddOutcome.new(status: :own_listing) if user_id.present? && listing.store.user_id == user_id

    requested = [ quantity.to_i, 1 ].max
    item = cart_items.find_by(listing_id: listing.id)
    target = (item&.quantity || 0) + requested
    capped = [ target, listing.quantity ].min
    status = if capped < target
      :capped
    elsif item
      :increased
    else
      :added
    end

    if item
      item.update!(quantity: capped)
    else
      item = cart_items.create!(listing: listing, quantity: capped, unit_price_cents: listing.price_cents)
    end
    AddOutcome.new(status: status, item: item)
  end

  # [store, items] pairs ordered by store name — the multi-seller layout of
  # the cart page. Listings (and stores) are preloaded for the view.
  def items_by_store
    cart_items.includes(listing: :store)
              .group_by { |item| item.listing.store }
              .sort_by { |store, _| store.display_name.downcase }
  end

  def subtotal_cents
    cart_items.sum("quantity * unit_price_cents")
  end

  # Total number of units in the cart (the header badge).
  def count
    cart_items.sum(:quantity)
  end

  # One shipping fee per distinct listing in the cart (sellers combine
  # parcels), not per unit.
  def shipping_cents
    Listing.where(id: cart_items.select(:listing_id)).sum(:shipping_price_cents)
  end

  # Drops items whose listing went invisible (sold, paused, vacation…) and
  # syncs price/stock drift back into the snapshot. Returns translated
  # notices for the cart page.
  def refresh!
    notices = []
    cart_items.includes(:listing).each do |item|
      listing = item.listing
      if !listing.visible_to_public?
        item.destroy!
        notices << I18n.t("carts.notices.removed", listing: listing.title)
        next
      end

      if item.unit_price_cents != listing.price_cents
        item.update!(unit_price_cents: listing.price_cents)
        notices << I18n.t("carts.notices.price_changed", listing: listing.title, price: listing.display_price)
      end
      if item.quantity > listing.quantity
        item.update!(quantity: listing.quantity)
        notices << I18n.t("carts.notices.quantity_capped", listing: listing.title, count: listing.quantity)
      end
    end
    notices
  end

  # Moves `other_cart`'s items into this cart (guest → user on sign-in),
  # re-running #add so stock caps, visibility and own-listing rules still
  # apply, then destroys the source cart.
  def merge!(other_cart)
    return if other_cart.nil? || other_cart.id == id

    other_cart.cart_items.includes(:listing).each do |item|
      add(item.listing, quantity: item.quantity)
    end
    other_cart.destroy!
  end

  private

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end
end
