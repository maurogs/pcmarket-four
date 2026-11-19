# Style tags sellers apply to their build listings ("rgb", "noctua", "lo_fi").
class SellerTag < ApplicationRecord
  include Translatable

  translated_fields :name

  has_many :listing_seller_tags, dependent: :destroy
  has_many :listings, through: :listing_seller_tags

  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/ }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
