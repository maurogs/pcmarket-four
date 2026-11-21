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

  def offer_price_active?
    offer_price_cents.to_i.positive? && offer_expires_at.present? && offer_expires_at > Time.current
  end

  def effective_price_cents
    offer_price_active? ? offer_price_cents.to_i : listing.price_cents.to_i
  end

  def subtotal_cents
    effective_price_cents * quantity
  end

  private

  def exactly_one_owner
    return if user_id.present? ^ cart_token.present?

    errors.add(:base, :single_owner_required)
  end
end
