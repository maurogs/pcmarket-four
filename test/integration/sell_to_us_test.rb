require "test_helper"

class SellToUsTest < ActionDispatch::IntegrationTest
  VALID_IBAN = "ES9121000418450200051332".freeze

  setup do
    @price = BuybackPrice.create!(
      item_kind: :gpu,
      item_model: "RTX 4070",
      base_price_cents: 50_000,
      condition_multipliers: BuybackPrice::CONDITION_MULTIPLIERS
    )
  end

  test "returns 404 for visitors while the flag is off" do
    get sell_to_us_path(locale: :en)

    assert_response :not_found
  end

  test "staff can preview the disabled feature" do
    sign_in users(:admin)

    get sell_to_us_path(locale: :en)

    assert_response :success
    assert_includes response.body, I18n.t("sell_to_us.preview_banner", locale: :en)
  end

  test "landing and quote form are public when the flag is on" do
    enable_feature!

    get sell_to_us_path(locale: :en)
    assert_response :success
    assert_includes response.body, I18n.t("sell_to_us.landing.title", locale: :en)

    get new_sell_offer_path(locale: :en)
    assert_response :success
    assert_select "select[name='buyback_price_id'] option", minimum: 1
  end

  test "quote endpoint renders an instant estimate in a Turbo Frame" do
    enable_feature!

    get sell_offer_quote_path(locale: :en, buyback_price_id: @price.id,
                              condition: "minor_wear", original_box: "1")

    assert_response :success
    assert_select "turbo-frame#buyback_estimate"
    assert_includes response.body, "€450"
  end

  test "signed-in user creates an offer with a seven day validity" do
    enable_feature!
    sign_in users(:buyer)

    assert_difference "SellOffer.count", 1 do
      post sell_offers_path(locale: :en), params: {
        buyback_price_id: @price.id,
        condition: "works_perfectly",
        original_box: "1",
        accessories: "Cable"
      }
    end

    offer = SellOffer.order(:id).last
    assert_redirected_to sell_offer_path(offer, locale: :en)
    assert offer.offered?
    assert_equal 52_500, offer.offered_price_cents
    assert_in_delta 7.days.from_now.to_f, offer.offer_expires_at.to_f, 60
    assert offer.original_box?
  end

  test "accepting an offer stores the IBAN encrypted" do
    enable_feature!
    sign_in users(:buyer)
    offer = create_offer

    post sell_offer_acceptance_path(offer, locale: :en),
         params: { payout_iban: VALID_IBAN, payout_account_name: "Bruno Buyer" }

    assert_redirected_to sell_offer_path(offer, locale: :en)
    offer.reload
    assert offer.accepted?
    assert_equal VALID_IBAN, offer.payout_iban
    assert_equal "Bruno Buyer", offer.payout_account_name

    raw = SellOffer.connection.select_value(
      SellOffer.sanitize_sql_array([ "SELECT payout_iban FROM sell_offers WHERE id = ?", offer.id ])
    )
    refute_equal VALID_IBAN, raw
  end

  test "invalid IBAN leaves the offer open" do
    enable_feature!
    sign_in users(:buyer)
    offer = create_offer

    post sell_offer_acceptance_path(offer, locale: :en),
         params: { payout_iban: "ES001234", payout_account_name: "Bruno Buyer" }

    assert_redirected_to sell_offer_path(offer, locale: :en)
    assert offer.reload.offered?
  end

  test "declining an offer closes it" do
    enable_feature!
    sign_in users(:buyer)
    offer = create_offer

    post sell_offer_decline_path(offer, locale: :en)

    assert offer.reload.declined?
    assert offer.declined_at.present?
  end

  test "admin moves received offers to paid and audits the change" do
    enable_feature!
    offer = create_offer
    offer.update!(status: :accepted, accepted_at: Time.current,
                  payout_iban: VALID_IBAN, payout_account_name: "Bruno Buyer")
    sign_in users(:admin)

    assert_difference "AdminAuditLog.count", 1 do
      patch admin_sell_offer_path(offer, locale: :en),
            params: { sell_offer: { status: "received", admin_notes: "Boxed and tested" } }
    end
    assert offer.reload.received?
    assert_equal "Boxed and tested", offer.admin_notes

    patch admin_sell_offer_path(offer, locale: :en), params: { sell_offer: { status: "paid" } }

    assert offer.reload.paid?
    assert offer.paid_at.present?
  end

  test "expiry job closes offers older than seven days" do
    enable_feature!
    offer = create_offer
    offer.update_columns(offer_expires_at: 1.day.ago)

    assert_difference "Notification.count", 1 do
      SellOfferExpiryJob.perform_now
    end

    assert offer.reload.expired?
  end

  test "admin can create, update and delete buyback prices" do
    sign_in users(:admin)

    get admin_buyback_prices_path(locale: :en)
    assert_response :success

    assert_difference "BuybackPrice.count", 1 do
      post admin_buyback_prices_path(locale: :en), params: {
        buyback_price: {
          item_kind: "cpu",
          item_model: "Ryzen 7 9800X3D",
          base_price_cents: 40_000,
          active: "1",
          position: 1,
          condition_multipliers: BuybackPrice::CONDITION_MULTIPLIERS
        }
      }
    end

    price = BuybackPrice.find_by!(item_model: "Ryzen 7 9800X3D")
    patch admin_buyback_price_path(price, locale: :en),
          params: { buyback_price: { base_price_cents: 42_000 } }
    assert_equal 42_000, price.reload.base_price_cents

    assert_difference "BuybackPrice.count", -1 do
      delete admin_buyback_price_path(price, locale: :en)
    end
  end

  private

  def enable_feature!
    Setting.set("sell_to_us_enabled", true)
  end

  def create_offer
    users(:buyer).sell_offers.create!(
      buyback_price: @price,
      item_kind: :gpu,
      item_name: @price.item_model,
      condition: "works_perfectly",
      offered_price_cents: 50_000,
      status: :offered,
      offer_expires_at: 7.days.from_now
    )
  end
end
