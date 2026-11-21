class SellOffersController < ApplicationController
  before_action :ensure_feature_available
  before_action :authenticate_user!, only: %i[create show]
  before_action :set_offer, only: :show

  def index
    @buyback_prices = BuybackPrice.active.ordered
    @gpu_prices = @buyback_prices.select(&:gpu?)
    @cpu_prices = @buyback_prices.select(&:cpu?)
    @offers = current_user ? current_user.sell_offers.recent.limit(20) : []
    set_meta_tags(
      title: t("sell_to_us.meta.title"),
      description: t("sell_to_us.meta.description")
    )
  end

  def new
    @buyback_prices = BuybackPrice.active.ordered
    @gpu_prices = @buyback_prices.select(&:gpu?)
    @cpu_prices = @buyback_prices.select(&:cpu?)
    @selected_price = selected_buyback_price
    @quote = build_quote
    set_meta_tags(
      title: t("sell_to_us.quote.title"),
      description: t("sell_to_us.meta.description")
    )
  end

  def create
    buyback_price = BuybackPrice.active.find(params[:buyback_price_id])
    quote = Buyback::Quote.call(
      buyback_price: buyback_price,
      condition: params[:condition],
      original_box: params[:original_box],
      accessories: params[:accessories]
    )

    unless quote.valid_condition?
      redirect_to new_sell_offer_path, alert: t("sell_to_us.errors.condition")
      return
    end

    offer = current_user.sell_offers.create!(
      buyback_price: buyback_price,
      item_kind: buyback_price.item_kind,
      item_name: buyback_price.item_model,
      condition: params[:condition],
      offered_price_cents: quote.total_cents,
      original_box: quote.original_box,
      accessories: params[:accessories].to_s.presence,
      status: :offered,
      offer_expires_at: SellOffer::OFFER_VALIDITY.from_now
    )

    SellOfferNotifier.call(offer, :offered)
    redirect_to sell_offer_path(offer), notice: t("sell_to_us.created")
  rescue ActiveRecord::RecordNotFound
    redirect_to new_sell_offer_path, alert: t("sell_to_us.errors.item_unavailable")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_sell_offer_path, alert: error.record.errors.full_messages.to_sentence
  end

  def show
    set_meta_tags(title: t("sell_to_us.offer.title", item: @offer.item_name), robots: "noindex,nofollow")
  end

  private

  def ensure_feature_available
    return if Setting.enabled?("sell_to_us_enabled")

    if current_user&.staff?
      @preview_mode = true
    else
      head :not_found
    end
  end

  def set_offer
    @offer = current_user.sell_offers.find(params[:id])
  end

  def selected_buyback_price
    return nil if params[:buyback_price_id].blank?

    BuybackPrice.active.find_by(id: params[:buyback_price_id])
  end

  def build_quote
    return nil unless @selected_price
    return nil unless Buyback::Quote::CONDITION_MULTIPLIERS.key?(params[:condition].to_s)

    Buyback::Quote.call(
      buyback_price: @selected_price,
      condition: params[:condition],
      original_box: params[:original_box],
      accessories: params[:accessories]
    )
  end
end
