class OrderItem < ApplicationRecord
  belongs_to :order, inverse_of: :order_items
  belongs_to :listing, inverse_of: :order_items

  validates :title_snapshot, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :listing_id, uniqueness: { scope: :order_id }

  def subtotal_cents
    price_cents * quantity
  end
end
