# Validates Spanish NIF (DNI), NIE and CIF identifiers including their
# check characters. Returns true only for structurally valid identifiers.
class SpanishTaxIdValidator
  NIF_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE".freeze
  CIF_LETTERS = "JABCDEFGHI".freeze
  NIE_PREFIXES = { "X" => "0", "Y" => "1", "Z" => "2" }.freeze
  CIF_PREFIXES = %w[A B C D E F G H J N P Q R S U V W].freeze
  CIF_LETTER_CONTROL = %w[K P Q S].freeze

  def self.valid?(value)
    new(value).valid?
  end

  def initialize(value)
    @value = value.to_s.strip.upcase.delete(" -")
  end

  def valid?
    return false unless @value.match?(/\A[A-Z0-9]{9}\z/)

    if @value.match?(/\A\d{8}[A-Z]\z/)
      valid_nif?
    elsif @value.match?(/\A[XYZ]\d{7}[A-Z]\z/)
      valid_nie?
    elsif @value.match?(/\A[A-Z]\d{7}[A-Z0-9]\z/)
      valid_cif?
    else
      false
    end
  end

  private

  def valid_nif?
    @value[-1] == NIF_LETTERS[@value[0, 8].to_i % 23]
  end

  def valid_nie?
    digits = NIE_PREFIXES.fetch(@value[0]) + @value[1, 7]
    @value[-1] == NIF_LETTERS[digits.to_i % 23]
  end

  def valid_cif?
    prefix = @value[0]
    return false unless CIF_PREFIXES.include?(prefix)

    digits = @value[1, 7]
    control = @value[-1]
    sum = 0
    digits.chars.each_with_index do |digit, index|
      number = digit.to_i
      if index.even?
        doubled = number * 2
        sum += doubled > 9 ? doubled - 9 : doubled
      else
        sum += number
      end
    end
    check_digit = (10 - (sum % 10)) % 10

    if CIF_LETTER_CONTROL.include?(prefix)
      control == CIF_LETTERS[check_digit]
    else
      control == check_digit.to_s || control == CIF_LETTERS[check_digit]
    end
  end
end
