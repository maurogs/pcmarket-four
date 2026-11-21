module Conversations
  class OffersController < ApplicationController
    before_action :authenticate_user!

    def create
      conversation = Conversation.for_participant(current_user).find(params[:conversation_id])
      amount_cents = Listing.parse_price_cents(params.dig(:offer, :amount))
      if amount_cents.blank?
        return redirect_to(conversation_path(conversation), alert: t("messaging.offers.invalid"))
      end

      message = conversation.messages.new(
        sender: current_user,
        kind: :offer,
        offer_amount_cents: amount_cents,
        body: I18n.t("messaging.offers.default_body", amount: helpers.format_price(amount_cents.to_i))
      )

      if message.save
        redirect_to conversation_path(conversation, anchor: "conversation-messages"),
                    notice: t("messaging.offers.sent")
      else
        redirect_to conversation_path(conversation),
                    alert: message.errors.full_messages.to_sentence.presence || t("messaging.offers.invalid")
      end
    end
  end
end
