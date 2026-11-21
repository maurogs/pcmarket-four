class Message < ApplicationRecord
  MAX_BODY_LENGTH = 2000

  belongs_to :conversation, inverse_of: :messages
  belongs_to :sender, class_name: "User", inverse_of: :messages

  enum :kind, { text: 0, offer: 1, system: 2 }
  enum :offer_status, { pending: 0, accepted: 1, declined: 2, expired: 3 }, prefix: :offer

  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }
  validates :offer_amount_cents, numericality: { only_integer: true, greater_than: 0 },
                                 allow_nil: true

  after_create :register_on_conversation

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) if read_at.nil?
  end

  private

  def register_on_conversation
    conversation.update_columns(last_message_at: created_at, updated_at: Time.current)

    counter = sender_id == conversation.buyer_id ? :seller_unread_count : :buyer_unread_count
    Conversation.where(id: conversation_id).update_counters(counter => 1)
  end
end
