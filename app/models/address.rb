class Address < ApplicationRecord
  belongs_to :user, inverse_of: :addresses
  belongs_to :region, optional: true, inverse_of: :addresses
  belongs_to :country, foreign_key: :country_code, primary_key: :code, optional: true,
                       inverse_of: false

  validates :full_name, :line1, :city, :postal_code, :country_code, presence: true

  scope :default_address, -> { where(default: true) }
  scope :ordered, -> { order(default: :desc, created_at: :desc) }

  before_validation :first_address_is_default, on: :create
  before_save :clear_other_defaults, if: :default?
  after_destroy :promote_remaining_default

  def full_address
    [ line1, line2, [ postal_code, city ].compact_blank.join(" "), region&.name, country&.name ]
      .compact_blank
      .join(", ")
  end

  private

  def first_address_is_default
    self.default = true if user.present? && user.addresses.empty?
  end

  def clear_other_defaults
    user.addresses.where.not(id: id).update_all(default: false, updated_at: Time.current)
  end

  def promote_remaining_default
    return unless default?
    return unless user.present?

    fallback = user.addresses.order(created_at: :desc).first
    fallback&.update_columns(default: true, updated_at: Time.current)
  end
end
