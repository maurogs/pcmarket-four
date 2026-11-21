module SellOffers
  class QuotesController < ApplicationController
    before_action :ensure_feature_available

    def show
      @buyback_price = BuybackPrice.active.find(params[:buyback_price_id])
      @quote = Buyback::Quote.call(
        buyback_price: @buyback_price,
        condition: params[:condition],
        original_box: params[:original_box],
        accessories: params[:accessories]
      )
      render partial: "sell_offers/estimate",
             locals: { quote: @quote, buyback_price: @buyback_price }
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def ensure_feature_available
      head :not_found unless Setting.enabled?("sell_to_us_enabled") || current_user&.staff?
    end
  end
end
