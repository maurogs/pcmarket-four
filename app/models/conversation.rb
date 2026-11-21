class Conversation < ApplicationRecord
  belongs_to :listing, optional: true, inverse_of: :conversations
  belongs_to :buyer, class_name: "User", inverse_of: :conversations_as_buyer
  belongs_to :seller, class_name: "User", inverse_of: :conversations_as_seller

  has_many :messages, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :conversation

  validates :buyer_id, uniqueness: { scope: [ :listing_id, :seller_id ] }
  validate :participants_must_differ

  def unread_count_for(user)
    user.id == buyer_id ? buyer_unread_count : seller_unread_count
  end

  def participant?(user)
    user.present? && [ buyer_id, seller_id ].include?(user.id)
  end

  private

  def participants_must_differ
    return if buyer_id.blank? || seller_id.blank?
    return if buyer_id != seller_id

    errors.add(:seller_id, :must_differ)
  end
end
