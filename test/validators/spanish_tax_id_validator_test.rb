require "test_helper"

class SpanishTaxIdValidatorTest < ActiveSupport::TestCase
  test "accepts valid NIF numbers" do
    %w[12345678Z 00000000T 87654321X].each do |value|
      assert SpanishTaxIdValidator.valid?(value), "expected #{value} to be valid"
    end
  end

  test "rejects invalid NIF numbers" do
    %w[12345678A 1234567Z 123456789].each do |value|
      assert_not SpanishTaxIdValidator.valid?(value), "expected #{value} to be invalid"
    end
  end

  test "accepts valid NIE numbers" do
    %w[X1234567L Y1234567X Z1234567R].each do |value|
      assert SpanishTaxIdValidator.valid?(value), "expected #{value} to be valid"
    end
  end

  test "rejects invalid NIE numbers" do
    %w[X1234567A Y1234567Z X123456L].each do |value|
      assert_not SpanishTaxIdValidator.valid?(value), "expected #{value} to be invalid"
    end
  end

  test "accepts valid CIF numbers with digit or letter control" do
    %w[B12345674 A58818501 P1234567D].each do |value|
      assert SpanishTaxIdValidator.valid?(value), "expected #{value} to be valid"
    end
  end

  test "rejects invalid CIF numbers" do
    %w[B12345670 A58818509 Q1234567A Z1234567B].each do |value|
      assert_not SpanishTaxIdValidator.valid?(value), "expected #{value} to be invalid"
    end
  end

  test "ignores spaces, hyphens and case" do
    assert SpanishTaxIdValidator.valid?(" 12345678-z ")
    assert SpanishTaxIdValidator.valid?("b12345674")
  end
end
