require "test_helper"

class OrderLifecycleMailerTest < ActionMailer::TestCase
  setup do
    @order = create_order(status: :shipped, locale: "en")
    @order.update_columns(carrier: "seur", tracking_number: "SE123456")
  end

  test "paid emails to buyer and seller in English and Spanish" do
    email = OrderMailer.paid_buyer(@order, locale: "en")
    assert_equal [ users(:buyer).email ], email.to
    assert_match(/payment/i, email.subject)
    assert_match(@order.number, email.body.encoded)

    I18n.with_locale(:es) do
      email = OrderMailer.paid_buyer(@order, locale: "es")
      assert_match(/Pago recibido/i, email.subject)
      assert_match("Hemos recibido el pago", email.body.encoded)

      seller_email = OrderMailer.paid_seller(@order, locale: "es")
      assert_equal [ users(:seller).email ], seller_email.to
      assert_match(/pedido/i, seller_email.subject)
    end
  end

  test "shipped email includes the carrier tracking link" do
    email = OrderMailer.shipped_buyer(@order, locale: "en")

    assert_equal [ users(:buyer).email ], email.to
    assert_match(/on its way/i, email.subject)
    assert_match(/SE123456/, email.body.encoded)
    assert_match(%r{seur\.com}, email.body.encoded)
  end

  test "delivered and completed emails ask for confirmation and a review" do
    delivered = create_order(status: :delivered, locale: "en")
    assert_match(/delivered/i, OrderMailer.delivered_buyer(delivered, locale: "en").subject)

    completed = create_order(status: :completed, locale: "en")
    assert_match(/completed/i, OrderMailer.completed_buyer(completed, locale: "en").subject)
    assert_match(/review/i, OrderMailer.completed_buyer(completed, locale: "en").body.encoded)
  end

  test "cancelled emails reach both parties in both languages" do
    assert_match(/cancelled/i, OrderMailer.cancelled_buyer(@order, locale: "en").subject)
    assert_equal [ users(:seller).email ], OrderMailer.cancelled_seller(@order, locale: "en").to

    I18n.with_locale(:es) do
      assert_match(/cancelado/i, OrderMailer.cancelled_buyer(@order, locale: "es").subject)
    end
  end

  test "dispute emails reach the seller and the support inbox" do
    @order.order_events.create!(kind: "dispute_opened", data: { "reason" => "damaged", "details" => "Broken" })

    seller_email = OrderMailer.dispute_seller(@order, locale: "es")
    assert_equal [ users(:seller).email ], seller_email.to
    assert_match(/disputa/i, seller_email.subject)
    assert_match("damaged", seller_email.body.encoded)

    admin_email = OrderMailer.dispute_admin(@order, to: "soporte@pcmarket.test", locale: "es")
    assert_equal [ "soporte@pcmarket.test" ], admin_email.to
    assert_match(/disputa/i, admin_email.subject)
  end

  test "late shipment email warns the seller" do
    email = OrderMailer.late_shipment_seller(@order, locale: "es")

    assert_equal [ users(:seller).email ], email.to
    assert_match(/envío/i, email.subject)
    assert_match("3", email.body.encoded)
  end
end
