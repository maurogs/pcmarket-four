class Block < ApplicationRecord
  belongs_to :blocker, class_name: "User", inverse_of: :blocks_made
  belongs_to :blocked, class_name: "User", inverse_of: :blocks_received

  validates :blocked_id, uniqueness: { scope: :blocker_id }
  validate :cannot_block_self

  private

  def cannot_block_self
    return if blocker_id.blank? || blocked_id.blank?
    return if blocker_id != blocked_id

    errors.add(:blocked_id, :cannot_block_self)
  end
end
