class MessageMailer < ApplicationMailer
  helper ApplicationHelper

  def notify(conversation, message, recipient, kind:)
    @conversation = conversation
    @message = message
    @recipient = recipient
    @kind = kind.to_s
    @listing = conversation.listing

    I18n.with_locale(locale_for(recipient)) do
      @url = conversation_url(conversation, locale: locale_for(recipient))
      mail(
        to: recipient.email,
        subject: t("messaging.mailer.#{@kind}.subject",
                   sender: message.sender.display_name,
                   listing: @listing&.title.to_s)
      )
    end
  end

  private

  def locale_for(user)
    candidate = user.locale.to_s
    I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale
  end
end
