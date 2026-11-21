class Notification < ApplicationRecord
  belongs_to :user, inverse_of: :notifications

  validates :kind, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  after_create_commit :broadcast_badge

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) if read_at.nil?
  end

  private

  def broadcast_badge
    broadcast_replace_to(
      user, :notifications,
      target: "notifications-badge",
      partial: "notifications/badge",
      locals: { count: user.notifications.unread.count }
    )
  end
end
