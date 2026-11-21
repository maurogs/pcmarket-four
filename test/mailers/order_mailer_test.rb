require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  setup do
    @order = orders(:delivered_order)
    @order.update!(locale: "en", payment_method: "bank_transfer", payment_provider: "bank_transfer",
                   buyer_email: "buyer@example.com")
  end

  test "buyer confirmation in English and Spanish" do
    email = OrderMailer.placed_buyer(@order)
    assert_equal [ "buyer@example.com" ], email.to
    assert_match(/order/i, email.subject)
    assert_match(@order.number, email.body.encoded)
    assert_match(Setting.get("bank_iban"), email.body.encoded)

    @order.update!(locale: "es")
    I18n.with_locale(:es) do
      email = OrderMailer.placed_buyer(@order)
      assert_match(/pedido/i, email.subject)
      assert_match("Gracias por tu pedido", email.body.encoded)
      assert_match(Setting.get("bank_beneficiary"), email.body.encoded)
    end
  end

  test "seller notification in English and Spanish" do
    email = OrderMailer.placed_seller(@order)
    assert_equal [ users(:seller).email ], email.to
    assert_match(/new order/i, email.subject)
    assert_match(@order.number, email.body.encoded)

    @order.update!(locale: "es")
    I18n.with_locale(:es) do
      email = OrderMailer.placed_seller(@order)
      assert_match(/nuevo pedido/i, email.subject)
      assert_match("Tienes un pedido nuevo", email.body.encoded)
    end
  end

  test "guest confirmation includes the signed access link" do
    @order.update_columns(buyer_id: nil, guest_access_token: "guest-token-123")

    email = OrderMailer.placed_buyer(@order)

    assert_match(/token=guest-token-123/, email.text_part.body.decoded)
  end
end
