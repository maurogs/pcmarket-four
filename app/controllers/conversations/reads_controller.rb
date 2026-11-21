module Conversations
  class ReadsController < ApplicationController
    before_action :authenticate_user!

    def create
      conversation = Conversation.for_participant(current_user).find(params[:conversation_id])
      conversation.mark_read_for!(current_user)
      redirect_to conversation_path(conversation), notice: t("messaging.thread.marked_read")
    end
  end
end
