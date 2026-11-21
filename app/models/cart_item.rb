class CartItem < ApplicationRecord
  belongs_to :user, optional: true, inverse_of: false
  belongs_to :listing, inverse_of: :cart_items

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :user_id, uniqueness: { scope: :listing_id }, if: -> { user_id.present? }
  validates :cart_token, uniqueness: { scope: :listing_id }, if: -> { cart_token.present? }
  validate :exactly_one_owner

  def owner
    user || cart_token
  end

  def subtotal_cents
    listing.price_cents * quantity
  end

  private

  def exactly_one_owner
    return if user_id.present? ^ cart_token.present?

    errors.add(:base, :single_owner_required)
  end
end
