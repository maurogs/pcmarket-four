module Messages
  class OfferResponsesController < ApplicationController
    before_action :authenticate_user!

    def create
      message = Message.joins(:conversation)
                       .where(conversations: { id: Conversation.for_participant(current_user).select(:id) })
                       .find(params[:message_id])
      conversation = message.conversation

      OfferResponse.new(
        message: message,
        actor: current_user,
        decision: params[:decision],
        amount_cents: Listing.parse_price_cents(params[:amount])
      ).call

      redirect_to conversation_path(conversation),
                  notice: t("messaging.offers.response_sent")
    rescue OfferResponse::Error => error
      redirect_to conversation_path(conversation || conversations_path),
                  alert: t("messaging.offers.errors.#{error.message_key}", default: t("messaging.offers.invalid"))
    rescue ActiveRecord::RecordInvalid
      redirect_to conversation_path(conversation || conversations_path),
                  alert: t("messaging.offers.invalid")
    end
  end
end
