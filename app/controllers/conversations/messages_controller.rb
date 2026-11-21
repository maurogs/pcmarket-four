module Conversations
  class MessagesController < ApplicationController
    before_action :authenticate_user!

    def create
      conversation = Conversation.for_participant(current_user).find(params[:conversation_id])
      return redirect_to(conversation_path(conversation), alert: t("messaging.errors.chat_disabled")) unless Setting.enabled?("chat_enabled")
      return redirect_to(conversation_path(conversation), alert: t("messaging.errors.blocked")) if conversation.blocked?

      message = conversation.messages.new(sender: current_user, body: params.dig(:message, :body).presence || params[:body])

      if message.save
        redirect_to conversation_path(conversation, anchor: "conversation-messages")
      else
        redirect_to conversation_path(conversation),
                    alert: message.errors.full_messages.to_sentence.presence || t("messaging.errors.message_invalid")
      end
    end
  end
end
