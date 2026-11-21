module Admin
  class BuybackPricesController < BaseController
    before_action :set_buyback_price, only: %i[edit update destroy]

    def index
      authorize_admin!(BuybackPrice, :index?)
      @buyback_prices = BuybackPrice.ordered
    end

    def new
      authorize_admin!(BuybackPrice, :new?)
      @buyback_price = BuybackPrice.new(
        item_kind: params[:item_kind].presence || :gpu,
        base_price_cents: 10_000,
        condition_multipliers: BuybackPrice::CONDITION_MULTIPLIERS,
        position: BuybackPrice.maximum(:position).to_i + 1
      )
    end

    def create
      authorize_admin!(BuybackPrice, :create?)
      @buyback_price = BuybackPrice.new(buyback_price_params)
      if @buyback_price.save
        audit!("buyback_price.created", @buyback_price)
        redirect_to admin_buyback_prices_path, notice: t("admin.buyback_prices.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_admin!(@buyback_price, :edit?)
    end

    def update
      authorize_admin!(@buyback_price, :update?)
      if @buyback_price.update(buyback_price_params)
        audit!("buyback_price.updated", @buyback_price)
        redirect_to admin_buyback_prices_path, notice: t("admin.buyback_prices.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_admin!(@buyback_price, :destroy?)
      @buyback_price.destroy!
      audit!("buyback_price.deleted", @buyback_price, changeset: { "item_model" => @buyback_price.item_model })
      redirect_to admin_buyback_prices_path, notice: t("admin.buyback_prices.deleted")
    end

    private

    def set_buyback_price
      @buyback_price = BuybackPrice.find(params[:id])
    end

    def buyback_price_params
      params.require(:buyback_price).permit(
        :item_kind, :item_model, :base_price_cents, :active, :position,
        condition_multipliers: BuybackPrice::CONDITION_MULTIPLIERS.keys
      )
    end
  end
end
