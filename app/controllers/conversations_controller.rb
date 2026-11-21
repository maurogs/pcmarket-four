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

  # Messaging ships in a later phase. The resource exists now so listing pages
  # can link to a stable endpoint; this creates the thread and opens it.
  def create
    listing = Listing.where(status: [ :published, :sold ]).find(params[:listing_id])

    if listing.user_id == current_user.id
      redirect_to listing_path(listing), alert: t("conversations.own_listing") and return
    end

    conversation = Conversation.find_or_create_by!(
      buyer_id: current_user.id, seller_id: listing.user_id, listing_id: listing.id
    )

    redirect_to conversation_path(conversation), notice: t("conversations.started")
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
