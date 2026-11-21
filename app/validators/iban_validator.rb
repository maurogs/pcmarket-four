class IbanValidator < ActiveModel::EachValidator
  FORMAT = /\A[A-Z]{2}\d{2}[A-Z0-9]{11,30}\z/

  def validate_each(record, attribute, value)
    iban = value.to_s.delete(" ").upcase
    return if iban.blank?

    unless iban.match?(FORMAT) && valid_checksum?(iban)
      record.errors.add(attribute, :invalid)
    end
  end

  private

  def valid_checksum?(iban)
    rearranged = iban[4..] + iban[0, 4]
    digits = rearranged.chars.map { |char| char.match?(/\d/) ? char : (char.ord - 55).to_s }.join
    digits.to_i % 97 == 1
  end
end
