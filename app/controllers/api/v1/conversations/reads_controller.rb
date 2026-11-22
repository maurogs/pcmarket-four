module Api
  module V1
    module Conversations
      class ReadsController < BaseController
        before_action :authenticate!

        def create
          conversation = Conversation.for_participant(current_user)
                                     .includes(:listing, :buyer, :seller)
                                     .find(params[:conversation_id])
          conversation.mark_read_for!(current_user)
          @conversation = conversation
          scope = conversation.messages.includes(:sender).order(created_at: :desc, id: :desc)
          @messages, @pagy = paginate(scope)
          @next_before = @pagy.page < @pagy.pages ? @messages.last&.id : nil

          render "api/v1/conversations/show", formats: :json
        end
      end
    end
  end
end
