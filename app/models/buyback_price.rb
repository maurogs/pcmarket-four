class BuybackPrice < ApplicationRecord
  CONDITION_MULTIPLIERS = {
    "works_perfectly" => 1.0,
    "minor_wear" => 0.85,
    "heavy_wear" => 0.65
  }.freeze

  enum :item_kind, { gpu: 0, cpu: 1 }

  has_many :sell_offers, dependent: :nullify, inverse_of: :buyback_price

  validates :item_model, presence: true, uniqueness: { scope: :item_kind }
  validates :base_price_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :condition_multipliers_are_valid

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:item_kind, :position, :item_model) }
  scope :for_kind, ->(kind) { where(item_kind: kind) }

  def multiplier_for(condition)
    condition_multipliers.to_h.fetch(condition.to_s, 1.0).to_f
  end

  private

  def condition_multipliers_are_valid
    return if condition_multipliers.blank?

    unknown = condition_multipliers.keys.map(&:to_s) - CONDITION_MULTIPLIERS.keys
    errors.add(:condition_multipliers, :invalid) if unknown.any?

    condition_multipliers.each_value do |value|
      multiplier = value.to_f
      errors.add(:condition_multipliers, :invalid) unless multiplier.positive? && multiplier <= 1.5
    end
  end
end
