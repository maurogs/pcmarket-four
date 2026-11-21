require "test_helper"

class MessageSafetyScannerTest < ActiveSupport::TestCase
  test "detects email addresses" do
    assert MessageSafetyScanner.call("Escríbeme a vendedor@example.com")[:flagged]
    assert_includes MessageSafetyScanner.call("mail me at john.doe@example.co.uk")[:reasons], :email
  end

  test "detects Spanish and English phone numbers" do
    assert_includes MessageSafetyScanner.call("Llámame al +34 612 345 678")[:reasons], :phone
    assert_includes MessageSafetyScanner.call("Call me on 07700 900123")[:reasons], :phone
    assert_not_includes MessageSafetyScanner.call("El precio es 549 euros")[:reasons], :phone
  end

  test "detects IBANs with or without spaces" do
    assert_includes MessageSafetyScanner.call("IBAN ES91 2100 0418 4502 0005 1332")[:reasons], :iban
  end

  test "detects off-platform payment requests" do
    %w[Bizum].concat([ "PayPal Friends", "Western Union", "transferencia fuera" ]).each do |term|
      result = MessageSafetyScanner.call("Puedes pagar por #{term}")
      assert_includes result[:reasons], :external_payment, term
    end
  end

  test "leaves clean marketplace messages unflagged" do
    result = MessageSafetyScanner.call("¿Sigue disponible la tarjeta? Puedo recogerla en Madrid.")

    assert_not result[:flagged]
    assert_empty result[:reasons]
  end
end
