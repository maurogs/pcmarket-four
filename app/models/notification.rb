class Notification < ApplicationRecord
  belongs_to :user, inverse_of: :notifications

  validates :kind, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) if read_at.nil?
  end
end
