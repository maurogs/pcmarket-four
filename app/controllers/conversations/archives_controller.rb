module Conversations
  class ArchivesController < ApplicationController
    before_action :authenticate_user!

    def create
      conversation = Conversation.for_participant(current_user).find(params[:conversation_id])
      conversation.archive_for!(current_user)
      redirect_to conversations_path(tab: "archived"), notice: t("messaging.thread.archived")
    end

    def destroy
      conversation = Conversation.for_participant(current_user).find(params[:conversation_id])
      conversation.unarchive_for!(current_user)
      redirect_to conversation_path(conversation), notice: t("messaging.thread.unarchived")
    end
  end
end
