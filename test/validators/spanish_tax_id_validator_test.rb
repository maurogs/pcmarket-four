require "test_helper"

class SpanishTaxIdValidatorTest < ActiveSupport::TestCase
  # Minimal carrier so the validator can be exercised in isolation.
  class Taxed
    include ActiveModel::Model
    attr_accessor :tax_id
    validates :tax_id, spanish_tax_id: true
  end

  def assert_valid(tax_id)
    taxed = Taxed.new(tax_id: tax_id)
    assert_predicate taxed, :valid?, "#{tax_id.inspect} should be valid"
  end

  def assert_invalid(tax_id)
    taxed = Taxed.new(tax_id: tax_id)
    assert_not_predicate taxed, :valid?, "#{tax_id.inspect} should be invalid"
    assert_includes taxed.errors.attribute_names, :tax_id
  end

  # --- Blank values (presence is a separate, business-only validation) --------

  test "blank tax ids pass" do
    assert_valid nil
    assert_valid ""
    assert_valid "   "
  end

  # --- NIF ---------------------------------------------------------------------

  test "accepts a valid NIF" do
    assert_valid "12345678Z" # 12345678 % 23 = 14 → Z
    assert_valid "00000000T"
    assert_valid "99999999R" # 99999999 % 23 = 1 → R
  end

  test "NIF check is case- and space-insensitive" do
    assert_valid "12345678z"
    assert_valid " 12 34 56 78 Z "
  end

  test "rejects a NIF with the wrong check letter" do
    assert_invalid "12345678A"
    assert_invalid "12345678Y"
  end

  test "rejects malformed NIFs" do
    assert_invalid "1234567Z"   # only 7 digits
    assert_invalid "123456789"  # no letter
    assert_invalid "ABCDEFGHZ"  # no digits
    assert_invalid "12345678Z!" # trailing junk
  end

  # --- NIE ---------------------------------------------------------------------

  test "accepts a valid NIE" do
    assert_valid "X0000000T" # X → 0, 0 % 23 = 0 → T
    assert_valid "Y0000001S" # Y → 1, 10000001 % 23 = 15 → S
    assert_valid "Z0000000M" # Z → 2, 20000000 % 23 = 5 → M
    assert_valid "X1234567L" # 1234567 % 23 = 19 → L
  end

  test "rejects a NIE with the wrong check letter" do
    assert_invalid "X0000000A"
    assert_invalid "X1234567A"
  end

  test "rejects malformed NIEs" do
    assert_invalid "I1234567A" # I is neither an NIE prefix nor a CIF type
    assert_invalid "X12345678" # control character must be a letter
    assert_invalid "X123456A"  # only 6 digits
  end

  # --- CIF ---------------------------------------------------------------------

  test "accepts a well-formed CIF" do
    assert_valid "B12345678" # digit control
    assert_valid "B1234567J" # letter control (A–J)
    assert_valid "G00000000"
    assert_valid "Q1234567A"
    assert_valid "W12345670"
  end

  test "rejects a CIF with an invalid organisation-type letter" do
    assert_invalid "D12345678"
    assert_invalid "M12345678"
  end

  test "rejects a CIF with an invalid control character or shape" do
    assert_invalid "B1234567K" # control letter beyond J
    assert_invalid "B1234567"  # too short
    assert_invalid "B123456789" # too long
    assert_invalid "B12345678Z" # control letter beyond J
    assert_invalid "X1234567J" # reads as a NIE, but the check letter is wrong
  end

  # --- Through the Store model ---------------------------------------------------

  test "store business accounts are validated against the tax id format" do
    store = stores(:confirmed_store)

    assert_not store.update(
      kind: :business,
      business_name: "Retro Corner S.L.",
      tax_id: "12345678A"
    )
    assert_includes store.errors[:tax_id], I18n.t("activerecord.errors.models.store.attributes.tax_id.invalid")

    assert store.update(tax_id: "B12345678")
  end
end
