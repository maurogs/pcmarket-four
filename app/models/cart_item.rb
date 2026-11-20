# One line of a cart: a listing plus the quantity and the unit price
# snapshotted when it was added (Cart#refresh! keeps the snapshot in sync).
class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :listing

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :listing_id, uniqueness: { scope: :cart_id }

  def total_cents
    quantity * unit_price_cents
  end

  # True while the snapshot no longer matches the listing's current price.
  def price_changed?
    unit_price_cents != listing.price_cents
  end
end
