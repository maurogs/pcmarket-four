class MessageNotifier
  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message
  end

  def call
    return if message.system?

    recipient = message.conversation.other_party(message.sender)
    return if recipient.blank? || recipient.deleted?

    kind = notification_kind
    Notifier.call(
      recipient,
      kind,
      params: notification_params,
      url: Rails.application.routes.url_helpers.conversation_path(
        message.conversation, locale: recipient.locale
      )
    )

    enqueue_email(recipient, kind)
  end

  private

  attr_reader :message

  def notification_kind
    if message.offer?
      message.counter_to.present? ? "offer_countered" : "offer_received"
    else
      "message_received"
    end
  end

  def notification_params
    {
      conversation_id: message.conversation_id,
      sender: message.sender.display_name,
      listing: message.conversation.listing&.title.to_s,
      body: message.body.to_s.truncate(160),
      amount: message.offer_amount_cents
    }
  end

  def enqueue_email(recipient, kind)
    preference = message.offer? ? "email_offers" : "email_messages"
    return unless recipient.notify_by_email?(preference)
    return unless email_allowed?(recipient, kind)

    MessageMailer.notify(message.conversation, message, recipient, kind: kind).deliver_later
  end

  # At most one message email per conversation and recipient every 15 minutes.
  def email_allowed?(recipient, kind)
    return true if message.offer?

    key = "message-email/#{message.conversation_id}/#{recipient.id}/#{kind}"
    Rails.cache.write(key, true, expires_in: 15.minutes, unless_exist: true)
  end
end
