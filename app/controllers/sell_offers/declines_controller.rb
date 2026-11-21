module SellOffers
  class DeclinesController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_feature_available
    before_action :set_offer

    def create
      if @offer.decline!
        SellOfferNotifier.call(@offer, :declined)
        redirect_to sell_offer_path(@offer), notice: t("sell_to_us.declined")
      else
        redirect_to sell_offer_path(@offer), alert: t("sell_to_us.errors.decline")
      end
    end

    private

    def ensure_feature_available
      head :not_found unless Setting.enabled?("sell_to_us_enabled") || current_user&.staff?
    end

    def set_offer
      @offer = current_user.sell_offers.find(params[:sell_offer_id])
    end
  end
end
