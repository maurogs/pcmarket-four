class SellOffer < ApplicationRecord
  belongs_to :user, inverse_of: :sell_offers

  enum :item_kind, { gpu: 0, cpu: 1 }
  enum :status, {
    requested: 0,
    offered: 1,
    accepted: 2,
    received: 3,
    paid: 4,
    rejected: 5
  }

  validates :item_name, presence: true
  validates :offered_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :open, -> { where(status: %i[requested offered accepted]) }
end
