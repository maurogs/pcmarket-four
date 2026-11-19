# Shipping address owned by a user (Phase 2). ES addresses carry a
# SpanishProvince code whose two digits must match the postal code prefix.
class Address < ApplicationRecord
  SPAIN_CODE = "ES"
  SPANISH_POSTAL_CODE = /\A\d{5}\z/

  belongs_to :user
  belongs_to :country

  validates :label, length: { maximum: 50 }, allow_nil: true
  validates :first_name, :last_name, presence: true, length: { maximum: 100 }
  validates :company, length: { maximum: 100 }, allow_nil: true
  validates :street_line1, :city, presence: true, length: { maximum: 200 }
  validates :street_line2, length: { maximum: 200 }, allow_nil: true
  validates :postal_code, presence: true, length: { maximum: 20 }
  validates :phone, length: { maximum: 30 }, allow_nil: true

  validate :country_is_enabled
  validate :validate_spanish_location, if: :spain?

  before_validation { self.province = nil unless spain? }
  # The partial unique index on [user_id] WHERE default_shipping allows a
  # single default, so clear the previous one before flipping this row.
  before_save :unset_other_defaults, if: :default_shipping?
  after_create :become_default_when_first

  scope :defaults_first, -> { order(Arel.sql("default_shipping DESC, created_at ASC")) }

  # Promotes this address to the user's default, unsetting the others
  # atomically (the partial unique index would reject a transient overlap).
  def make_default!
    transaction do
      user.addresses.where.not(id: id).update_all(default_shipping: false)
      update!(default_shipping: true)
    end
  end

  def spain?
    country&.code == SPAIN_CODE
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def province_name
    return if province.blank?

    SpanishProvince.name(province)
  end

  # Display lines for an address block: recipient, company, streets,
  # postal code + city, province, country.
  def formatted_lines
    lines = [ full_name, company, street_line1, street_line2 ]
    lines << [ postal_code, city ].compact_blank.join(" ")
    lines << province_name if province.present?
    lines << country.name
    lines.compact_blank
  end

  def to_s
    formatted_lines.join(", ")
  end

  private

  def country_is_enabled
    errors.add(:country, :not_enabled) if country && !country.enabled?
  end

  def validate_spanish_location
    errors.add(:postal_code, :invalid) unless postal_code.to_s.match?(SPANISH_POSTAL_CODE)

    if province.blank?
      errors.add(:province, :blank)
    elsif !SpanishProvince.codes.include?(province)
      errors.add(:province, :inclusion)
    elsif postal_code.to_s.match?(SPANISH_POSTAL_CODE) && !postal_code.start_with?(province)
      # The first two postal-code digits are the province's INE code.
      errors.add(:province, :postal_code_mismatch)
    end
  end

  def unset_other_defaults
    user.addresses.where(default_shipping: true).where.not(id: id).update_all(default_shipping: false)
  end

  def become_default_when_first
    return if default_shipping?
    return if user.addresses.where(default_shipping: true).where.not(id: id).exists?

    update_column(:default_shipping, true)
  end
end
