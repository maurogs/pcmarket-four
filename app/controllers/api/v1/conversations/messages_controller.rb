module Api
  module V1
    module Conversations
      class MessagesController < BaseController
        before_action :authenticate!

        def create
          conversation = Conversation.for_participant(current_user).find(params[:conversation_id])

          unless Setting.enabled?("chat_enabled")
            return render_error("chat_disabled", t("api.errors.chat_disabled"), status: :forbidden)
          end

          if conversation.blocked?
            return render_error("blocked", t("api.errors.blocked"), status: :forbidden)
          end

          message = conversation.messages.new(
            sender: current_user,
            body: params[:body].presence || params.dig(:message, :body)
          )

          if message.save
            @message = message
            render :create, formats: :json, status: :created
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
