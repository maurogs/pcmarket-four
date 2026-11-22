class Device < ApplicationRecord
  PLATFORMS = %w[ios android].freeze

  belongs_to :user, inverse_of: :devices

  validates :platform, inclusion: { in: PLATFORMS }
  validates :token, presence: true, uniqueness: true

  before_validation :stamp_seen

  private

  def stamp_seen
    self.last_seen_at = Time.current
  end
end
