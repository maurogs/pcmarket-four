module Conversations
  class ReadAllsController < ApplicationController
    before_action :authenticate_user!

    def create
      Conversation.for_participant(current_user).find_each do |conversation|
        conversation.mark_read_for!(current_user)
      end
      redirect_to conversations_path, notice: t("messaging.inbox.marked_all_read")
    end
  end
end
