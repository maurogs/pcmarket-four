class Message < ApplicationRecord
  MAX_BODY_LENGTH = 2000
  RATE_LIMIT = 30
  RATE_WINDOW = 10.minutes
  OFFER_TTL = 48.hours
  MIN_OFFER_RATIO = 0.5

  belongs_to :conversation, inverse_of: :messages
  belongs_to :sender, class_name: "User", inverse_of: :messages

  enum :kind, { text: 0, offer: 1, system: 2 }
  enum :offer_status, { pending: 0, accepted: 1, declined: 2, expired: 3 }, prefix: :offer

  attr_accessor :counter_to

  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }
  validates :offer_amount_cents, presence: true,
                                 numericality: { only_integer: true, greater_than: 0 },
                                 if: :offer?
  validates :offer_amount_cents, numericality: { only_integer: true, greater_than: 0 },
                                 allow_nil: true
  validate :offer_must_fit_listing, if: :offer?
  validate :within_rate_limit, on: :create

  before_validation :scan_safety, if: -> { body.present? && (new_record? || will_save_change_to_body?) }
  before_validation :stamp_offer_expiry, on: :create, if: :offer?

  after_create :register_on_conversation
  after_create_commit :broadcast_message

  scope :flagged, -> { where(flagged: true) }
  scope :pending_offers, -> { offer.where(offer_status: offer_statuses[:pending]) }
  scope :expired_offers, lambda {
    pending_offers.where("COALESCE(offer_expires_at, created_at + INTERVAL '48 hours') <= ?", Time.current)
  }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) if read_at.nil?
  end

  def offer_expired?
    offer? && offer_expires_at.present? && offer_expires_at <= Time.current
  end

  def effective_offer_expiry
    offer_expires_at || (created_at ? created_at + OFFER_TTL : OFFER_TTL.from_now)
  end

  def accept_offer!(actor)
    respond_to_offer!(actor) do
      update!(offer_status: :accepted)
      conversation.offers.offer_pending.where.not(id: id)
                  .update_all(offer_status: self.class.offer_statuses[:declined])
    end
  end

  def decline_offer!(actor)
    respond_to_offer!(actor) { update!(offer_status: :declined) }
  end

  def expire!
    update!(offer_status: :expired) if offer_pending?
  end

  def safety_warning?
    flagged? && MessageSafetyScanner.call(body)[:flagged]
  end

  private

  def respond_to_offer!(actor)
    raise ActiveRecord::RecordInvalid, self unless conversation.participant?(actor)
    raise ActiveRecord::RecordInvalid, self if sender_id == actor.id
    raise ActiveRecord::RecordInvalid, self unless offer_pending?
    raise ActiveRecord::RecordInvalid, self if offer_expired?

    transaction do
      lock!
      yield
    end
    true
  end

  def offer_must_fit_listing
    listing = conversation&.listing
    if listing.blank?
      errors.add(:base, :offer_requires_listing)
      return
    end
    unless listing.accepts_offers?
      errors.add(:base, :offers_not_accepted)
      return
    end
    return if offer_amount_cents.blank?

    minimum = (listing.price_cents * MIN_OFFER_RATIO).ceil
    if offer_amount_cents >= listing.price_cents
      errors.add(:offer_amount_cents, :below_listing_price)
    elsif offer_amount_cents < minimum
      errors.add(:offer_amount_cents, :at_least_half)
    end
  end

  def within_rate_limit
    return if sender_id.blank?
    return if kind == "system"

    recent = self.class.where(sender_id: sender_id)
                       .where("created_at >= ?", RATE_WINDOW.ago)
                       .count
    return if recent < RATE_LIMIT

    errors.add(:base, :rate_limited)
  end

  def scan_safety
    self.flagged = MessageSafetyScanner.call(body)[:flagged]
  end

  def stamp_offer_expiry
    self.offer_expires_at ||= OFFER_TTL.from_now
    self.offer_status ||= :pending
  end

  def register_on_conversation
    conversation.update_columns(last_message_at: created_at, updated_at: Time.current)

    counter = sender_id == conversation.buyer_id ? :seller_unread_count : :buyer_unread_count
    Conversation.where(id: conversation_id).update_counters(counter => 1)
  end

  def broadcast_message
    broadcast_append_to(
      conversation,
      target: "conversation-messages",
      partial: "messages/message",
      locals: { message: self, viewer: nil }
    )

    conversation.participants_inbox_users.each do |user|
      broadcast_append_to(
        [ conversation, user ],
        target: "conversation-messages",
        partial: "messages/message",
        locals: { message: self, viewer: user }
      )
    end
    conversation.participants_inbox_users.each { |user| Conversation.broadcast_inbox_badge(user) }
    MessageNotifier.call(self)
  end
end
