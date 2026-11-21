class Address < ApplicationRecord
  belongs_to :user, inverse_of: :addresses
  belongs_to :region, optional: true, inverse_of: :addresses
  belongs_to :country, foreign_key: :country_code, primary_key: :code, optional: true,
                       inverse_of: false

  validates :full_name, :line1, :city, :postal_code, :country_code, presence: true

  scope :default_address, -> { where(default: true) }
  scope :ordered, -> { order(default: :desc, created_at: :desc) }

  def full_address
    [ line1, line2, [ postal_code, city ].compact_blank.join(" "), region&.name, country&.name ]
      .compact_blank
      .join(", ")
  end
end
