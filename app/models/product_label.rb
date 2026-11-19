# Marketing badges ("Value GPUs", "Pro Gamer CPUs") attached to listings.
# These are labels, not categories — sellers pick them per listing.
class ProductLabel < ApplicationRecord
  include Translatable

  translated_fields :name

  has_many :listing_labels, dependent: :destroy
  has_many :listings, through: :listing_labels

  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/ }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
