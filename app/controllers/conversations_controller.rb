class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @conversations = Conversation
      .where("buyer_id = :id OR seller_id = :id", id: current_user.id)
      .order(last_message_at: :desc, created_at: :desc)
  end

  def show
    @conversation = Conversation
      .where("buyer_id = :id OR seller_id = :id", id: current_user.id)
      .find(params[:id])
  end
end
