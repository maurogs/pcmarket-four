module Api
  module V1
    class ConversationsController < BaseController
      before_action :authenticate!

      def index
        tab = params[:tab].to_s
        tab = "chats" unless %w[chats offers archived blocked].include?(tab)
        scope = Conversation.inbox_for(current_user, tab: tab)
        @conversations, @pagy = paginate(scope)
        @tab = tab
        render :index, formats: :json
      end

      def show
        @conversation = Conversation.for_participant(current_user)
                                    .includes(:listing, :buyer, :seller, messages: :sender)
                                    .find(params[:id])
        @conversation.mark_read_for!(current_user)

        scope = @conversation.messages.includes(:sender).order(created_at: :desc, id: :desc)
        scope = scope.where("messages.id < ?", params[:before].to_i) if params[:before].to_i.positive?
        @messages, @pagy = paginate(scope)
        @next_before = @pagy.page < @pagy.pages ? @messages.last&.id : nil

        render :show, formats: :json
      end

      def create
        conversation = ConversationStarter.new(
          user: current_user,
          listing: listing,
          seller: params[:seller_id],
          store: store,
          body: params[:body] || params[:first_message],
          offer_amount_cents: offer_amount_cents
        ).call

        @conversation = conversation
        scope = conversation.messages.includes(:sender).order(created_at: :desc, id: :desc)
        @messages, @pagy = paginate(scope)
        @next_before = nil
        render :show, formats: :json, status: :created
      rescue ConversationStarter::Error => error
        render_error("conversation_failed", t("messaging.errors.#{error.message_key}",
                                               default: t("api.errors.listing_unavailable")),
                     status: :unprocessable_entity)
      end

      private

      def listing
        return nil if params[:listing_id].blank?

        Listing.where(status: %i[published sold paused]).find(params[:listing_id])
      end

      def store
        return nil if params[:store_id].blank?

        Store.friendly.find(params[:store_id])
      end

      def offer_amount_cents
        return nil if params[:offer_amount].blank?

        Listing.parse_price_cents(params[:offer_amount])
      end
    end
  end
end
