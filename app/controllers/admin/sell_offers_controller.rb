module Admin
  class SellOffersController < BaseController
    before_action :set_sell_offer, only: %i[show update]

    def index
      authorize_admin!(SellOffer, :index?)
      scope = SellOffer.includes(:user, :buyback_price).recent
      scope = scope.where(status: params[:status]) if params[:status].present? && SellOffer.statuses.key?(params[:status])
      @pagy, @offers = pagy(scope, limit: pagination_limit)
      @status_counts = SellOffer.group(:status).count
    end

    def show
      authorize_admin!(@sell_offer, :show?)
    end

    def update
      authorize_admin!(@sell_offer, :update?)
      status = params.dig(:sell_offer, :status).to_s
      notes = params.dig(:sell_offer, :admin_notes)

      unless %w[received paid rejected].include?(status)
        redirect_to admin_sell_offer_path(@sell_offer), alert: t("admin.sell_offers.invalid_status")
        return
      end

      event = status.to_sym
      changed = case status
      when "received" then @sell_offer.mark_received!(notes: notes)
      when "paid" then @sell_offer.mark_paid!(notes: notes)
      when "rejected" then @sell_offer.reject!(notes: notes)
      end

      if changed
        audit!("sell_offer.#{status}", @sell_offer)
        SellOfferNotifier.call(@sell_offer, event)
        redirect_to admin_sell_offer_path(@sell_offer), notice: t("admin.sell_offers.updated")
      else
        redirect_to admin_sell_offer_path(@sell_offer), alert: t("admin.sell_offers.invalid_transition")
      end
    end

    private

    def set_sell_offer
      @sell_offer = SellOffer.find(params[:id])
    end
  end
end
