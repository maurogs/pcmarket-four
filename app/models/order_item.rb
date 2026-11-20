# One line of an order: everything is snapshotted at placement time so the
# row stays truthful after the listing is edited, sold out or deleted
# (listing_id nullifies — see the order_items migration).
class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :listing, optional: true

  validates :title, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, :line_total_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :condition, inclusion: { in: Listing.conditions.keys }, allow_nil: true
end
