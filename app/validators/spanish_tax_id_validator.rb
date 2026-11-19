# Validates Spanish tax identifiers:
#
#   NIF  12345678Z   8 digits + mod-23 check letter (TRWAGMYFPDXBNJZSQVHLCKE)
#   NIE  X1234567Z   X/Y/Z (→ 0/1/2) + 7 digits + the same mod-23 letter
#   CIF  B12345678   organisation-type letter + 7 digits + control character
#                    (digit or A–J) — format check only: the control
#                    algorithm depends on the organisation type.
#
# Blank values pass; presence is a separate (business-only) validation.
class SpanishTaxIdValidator < ActiveModel::EachValidator
  CHECK_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE".freeze
  NIE_PREFIX_VALUES = { "X" => 0, "Y" => 1, "Z" => 2 }.freeze
  CIF_ORGANISATION_TYPES = %w[A B E G H J K L N P Q S U V W].freeze

  NIF_PATTERN = /\A(\d{8})([A-Z])\z/
  NIE_PATTERN = /\A([XYZ])(\d{7})([A-Z])\z/
  CIF_PATTERN = /\A([A-Z])(\d{7})([0-9A-J])\z/

  def validate_each(record, attribute, value)
    tax_id = value.to_s.strip.upcase.delete(" ")
    return if tax_id.blank?

    record.errors.add(attribute, options[:message] || :invalid) unless valid?(tax_id)
  end

  private

  def valid?(tax_id)
    if (match = NIF_PATTERN.match(tax_id))
      check_letter(match[1]) == match[2]
    elsif (match = NIE_PATTERN.match(tax_id))
      check_letter("#{NIE_PREFIX_VALUES.fetch(match[1])}#{match[2]}") == match[3]
    elsif (match = CIF_PATTERN.match(tax_id))
      CIF_ORGANISATION_TYPES.include?(match[1])
    else
      false
    end
  end

  def check_letter(digits)
    CHECK_LETTERS[digits.to_i % CHECK_LETTERS.length]
  end
end
