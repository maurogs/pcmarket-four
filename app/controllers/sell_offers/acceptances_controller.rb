module SellOffers
  class AcceptancesController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_feature_available
    before_action :set_offer

    def create
      if @offer.accept!(iban: params[:payout_iban], account_name: params[:payout_account_name])
        SellOfferNotifier.call(@offer, :accepted)
        redirect_to sell_offer_path(@offer), notice: t("sell_to_us.accepted")
      else
        redirect_to sell_offer_path(@offer), alert: t("sell_to_us.errors.accept")
      end
    rescue ActiveRecord::RecordInvalid => error
      redirect_to sell_offer_path(@offer), alert: error.record.errors.full_messages.to_sentence
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
