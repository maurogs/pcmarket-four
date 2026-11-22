class Conversation < ApplicationRecord
  belongs_to :listing, optional: true, inverse_of: :conversations
  belongs_to :buyer, class_name: "User", inverse_of: :conversations_as_buyer
  belongs_to :seller, class_name: "User", inverse_of: :conversations_as_seller

  has_many :messages, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :conversation

  validates :buyer_id, uniqueness: { scope: [ :listing_id, :seller_id ] }
  validate :participants_must_differ

  scope :for_participant, lambda { |user|
    where("buyer_id = :id OR seller_id = :id", id: user.id)
  }
  scope :active_for, lambda { |user|
    for_participant(user).where(
      "CASE WHEN buyer_id = :id THEN buyer_archived_at IS NULL ELSE seller_archived_at IS NULL END",
      id: user.id
    )
  }
  scope :archived_for, lambda { |user|
    for_participant(user).where(
      "CASE WHEN buyer_id = :id THEN buyer_archived_at IS NOT NULL ELSE seller_archived_at IS NOT NULL END",
      id: user.id
    )
  }
  scope :with_offers, lambda {
    joins(:messages).where(messages: { kind: Message.kinds[:offer] }).distinct
  }

  def self.inbox_for(user, tab: "chats")
    base = for_participant(user).includes(
      :messages, :listing, :buyer, :seller, { listing: { images_attachments: :blob } }
    )
    case tab.to_s
    when "offers"
      base.active_for(user).where(id: Message.offer.select(:conversation_id))
    when "archived"
      base.archived_for(user)
    else
      base.active_for(user)
    end.order(Arel.sql("last_message_at IS NULL ASC, last_message_at DESC, created_at DESC"))
  end

  def self.unread_total_for(user)
    where(buyer_id: user.id).sum(:buyer_unread_count) +
      where(seller_id: user.id).sum(:seller_unread_count)
  end

  def self.broadcast_inbox_badge(user)
    return if user.blank? || Current.seeding

    user.broadcast_replace_to(
      [ user, :inbox ],
      target: "inbox-badge",
      partial: "messaging/inbox_badge",
      locals: { count: unread_total_for(user) }
    )
  end

  def participant?(user)
    user.present? && [ buyer_id, seller_id ].include?(user.id)
  end

  def other_party(user)
    user.id == buyer_id ? seller : buyer
  end

  def participants
    [ buyer, seller ].compact
  end

  alias participants_inbox_users participants

  def unread_count_for(user)
    user.id == buyer_id ? buyer_unread_count : seller_unread_count
  end

  def archived_for?(user)
    user.id == buyer_id ? buyer_archived_at.present? : seller_archived_at.present?
  end

  def archive_for!(user)
    column = user.id == buyer_id ? :buyer_archived_at : :seller_archived_at
    update_column(column, Time.current)
  end

  def unarchive_for!(user)
    column = user.id == buyer_id ? :buyer_archived_at : :seller_archived_at
    update_column(column, nil)
  end

  def mark_read_for!(user)
    return if user.blank? || !participant?(user)

    transaction do
      messages.where.not(sender_id: user.id).where(read_at: nil).update_all(read_at: Time.current)
      column = user.id == buyer_id ? :buyer_unread_count : :seller_unread_count
      update_columns(column => 0)
    end
    self.class.broadcast_inbox_badge(user)
  end

  def blocked?
    Block.between?(buyer, seller)
  end

  def last_message
    messages.last
  end

  def unread_messages_for(user)
    messages.where.not(sender_id: user.id).where(read_at: nil)
  end

  def offers
    messages.where(kind: Message.kinds[:offer])
  end

  private

  def participants_must_differ
    return if buyer_id.blank? || seller_id.blank?
    return if buyer_id != seller_id

    errors.add(:seller_id, :must_differ)
  end
end
