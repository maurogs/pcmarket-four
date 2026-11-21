class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: :show

  def index
    @tab = inbox_tab
    @conversations = Conversation.inbox_for(current_user, tab: @tab)
    @blocked_users = blocked_users if @tab == "blocked"
    @active_conversation = @conversations.first if @tab != "blocked"
    @conversations = @conversations.limit(100)
  end

  def show
    @conversation.mark_read_for!(current_user)
    @conversations = Conversation.inbox_for(current_user).limit(100)
    @messages = @conversation.messages.includes(:sender).to_a
    @listing = @conversation.listing
  end

  def create
    conversation = ConversationStarter.new(
      user: current_user,
      listing: listing,
      seller: params[:seller_id],
      store: store,
      body: params[:first_message].presence || params[:body],
      offer_amount_cents: offer_amount_cents
    ).call

    redirect_to conversation_path(conversation),
                notice: t("conversations.started")
  rescue ConversationStarter::Error => error
    redirect_back fallback_location: (listing ? listing_path(listing) : conversations_path),
                  alert: t("messaging.errors.#{error.message_key}", default: t("conversations.cannot_start"))
  end

  private

  def set_conversation
    @conversation = Conversation.for_participant(current_user).find(params[:id])
  end

  def inbox_tab
    tab = params[:tab].to_s
    %w[chats offers archived blocked].include?(tab) ? tab : "chats"
  end

  def listing
    return nil if params[:listing_id].blank?

    Listing.where(status: %i[published sold paused]).find(params[:listing_id])
  end

  def store
    return nil if params[:store_id].blank?

    Store.friendly.find(params[:store_id])
  end

  def blocked_users
    User.where(
      id: Block.where(blocker_id: current_user.id).select(:blocked_id)
    ).or(User.where(id: Block.where(blocked_id: current_user.id).select(:blocker_id))).to_a
  end

  def offer_amount_cents
    return nil if params[:offer_amount].blank?

    Listing.parse_price_cents(params[:offer_amount])
  end
end
