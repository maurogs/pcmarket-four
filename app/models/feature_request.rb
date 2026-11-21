class FeatureRequest < ApplicationRecord
  belongs_to :listing, inverse_of: false
  belongs_to :user, inverse_of: false

  enum :status, { pending: 0, paid: 1, active: 2, expired: 3 }

  validates :days, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 90 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }

  def approve!
    transaction do
      update!(status: :paid, paid_at: Time.current)
      listing.update!(featured_until: [ listing.featured_until, Time.current ].compact.max + days.days,
                      labels: (listing.labels + [ "featured" ]).uniq)
      update!(status: :active)
    end
  end
end
