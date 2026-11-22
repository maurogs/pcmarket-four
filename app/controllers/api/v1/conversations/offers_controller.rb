module Api
  module V1
    module Conversations
      class OffersController < BaseController
        before_action :authenticate!

        def create
          conversation = Conversation.for_participant(current_user).find(params[:conversation_id])
          amount_cents = Listing.parse_price_cents(params[:amount] || params.dig(:offer, :amount))

          if amount_cents.blank?
            return render_error("invalid_amount", t("api.errors.invalid_amount"),
                                status: :unprocessable_entity)
          end

          message = conversation.messages.new(
            sender: current_user,
            kind: :offer,
            offer_amount_cents: amount_cents,
            body: params[:body].presence || I18n.t("messaging.offers.default_body",
                                                  amount: ApplicationController.helpers.format_price(amount_cents.to_i))
          )

          if message.save
            @message = message
            render "api/v1/conversations/messages/create", formats: :json, status: :created
          else
            render_error("validation_failed", t("api.errors.validation_failed"),
                         status: :unprocessable_entity,
                         details: message.errors.to_hash.transform_values { |messages| Array(messages) })
          end
        end
      end
    end
  end
end
