class Block < ApplicationRecord
  belongs_to :blocker, class_name: "User", inverse_of: :blocks_made
  belongs_to :blocked, class_name: "User", inverse_of: :blocks_received

  validates :blocked_id, uniqueness: { scope: :blocker_id }
  validate :cannot_block_self

  scope :involving, ->(user) { where(blocker_id: user.id).or(where(blocked_id: user.id)) }

  def self.between?(first, second)
    return false if first.blank? || second.blank?

    where(blocker_id: first.id, blocked_id: second.id)
      .or(where(blocker_id: second.id, blocked_id: first.id))
      .exists?
  end

  private

  def cannot_block_self
    return if blocker_id.blank? || blocked_id.blank?
    return if blocker_id != blocked_id

    errors.add(:blocked_id, :cannot_block_self)
  end
end
