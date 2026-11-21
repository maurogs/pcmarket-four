module Buyback
  # Prices a trade-in from a BuybackPrice row. The estimate is deliberately
  # deterministic: condition multiplier and an optional original-box bonus.
  class Quote
    CONDITION_MULTIPLIERS = BuybackPrice::CONDITION_MULTIPLIERS
    BOX_BONUS_RATE = 0.05

    attr_reader :buyback_price, :condition, :original_box, :accessories

    def self.call(**attributes)
      new(**attributes).tap(&:calculate)
    end

    def initialize(buyback_price:, condition:, original_box: false, accessories: nil)
      @buyback_price = buyback_price
      @condition = condition.to_s
      @original_box = ActiveModel::Type::Boolean.new.cast(original_box) == true
      @accessories = accessories.to_s
    end

    def calculate
      @base_cents = buyback_price.base_price_cents.to_i
      @condition_multiplier = multiplier
      @condition_cents = (@base_cents * @condition_multiplier).round
      @box_bonus_cents = @original_box ? (@base_cents * BOX_BONUS_RATE).round : 0
      @total_cents = @condition_cents + @box_bonus_cents
      self
    end

    attr_reader :base_cents, :condition_multiplier, :condition_cents, :box_bonus_cents, :total_cents

    def valid_condition?
      CONDITION_MULTIPLIERS.key?(condition)
    end

    def original_box?
      original_box
    end

    def to_h
      {
        base_cents: base_cents,
        condition: condition,
        condition_multiplier: condition_multiplier,
        condition_cents: condition_cents,
        original_box: original_box,
        box_bonus_cents: box_bonus_cents,
        total_cents: total_cents
      }
    end

    private

    def multiplier
      return 1.0 unless valid_condition?

      configured = buyback_price.condition_multipliers.to_h[condition]
      (configured.presence || CONDITION_MULTIPLIERS.fetch(condition)).to_f
    end
  end
end
