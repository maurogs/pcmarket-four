module Api
  module V1
    module Messages
      class OfferResponsesController < BaseController
        before_action :authenticate!

        def create
          message = Message.joins(:conversation)
                           .where(conversations: { id: Conversation.for_participant(current_user).select(:id) })
                           .find(params[:message_id])

          result = OfferResponse.new(
            message: message,
            actor: current_user,
            decision: params[:decision],
            amount_cents: Listing.parse_price_cents(params[:amount])
          ).call

          @message = result
          render "api/v1/messages/show", formats: :json
        rescue OfferResponse::Error => error
          message = t("messaging.offers.errors.#{error.message_key}",
                      default: t("api.errors.offer_not_pending"))
          render_error("offer_failed", message, status: :unprocessable_entity)
        rescue ActiveRecord::RecordInvalid
          render_error("offer_failed", t("api.errors.offer_not_pending"),
                       status: :unprocessable_entity)
        end
      end
    end
  end
end
