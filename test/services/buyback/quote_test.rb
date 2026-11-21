require "test_helper"

module Buyback
  class QuoteTest < ActiveSupport::TestCase
    setup do
      @price = BuybackPrice.create!(
        item_kind: :gpu,
        item_model: "RTX 4070",
        base_price_cents: 50_000,
        condition_multipliers: BuybackPrice::CONDITION_MULTIPLIERS
      )
    end

    test "applies the condition multiplier and original box bonus" do
      quote = Quote.call(buyback_price: @price, condition: "minor_wear", original_box: true)

      assert_equal 50_000, quote.base_cents
      assert_equal 0.85, quote.condition_multiplier
      assert_equal 42_500, quote.condition_cents
      assert_equal 2_500, quote.box_bonus_cents
      assert_equal 45_000, quote.total_cents
      assert quote.original_box?
      assert quote.valid_condition?
    end

    test "perfect condition without box pays the base price" do
      quote = Quote.call(buyback_price: @price, condition: "works_perfectly")

      assert_equal 50_000, quote.total_cents
      assert_equal 0, quote.box_bonus_cents
    end

    test "unknown condition is rejected" do
      quote = Quote.call(buyback_price: @price, condition: "broken")

      refute quote.valid_condition?
    end

    test "buyback price validates multipliers" do
      price = BuybackPrice.new(item_kind: :cpu, item_model: "Test CPU", base_price_cents: 1000,
                               condition_multipliers: { "broken" => 0.5 })

      refute price.valid?
      assert price.errors[:condition_multipliers].any?
    end
  end
end
