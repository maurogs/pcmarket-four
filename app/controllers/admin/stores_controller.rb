module Admin
  class StoresController < BaseController
    before_action :set_store, only: %i[show edit update]

    def index
      authorize_admin!(Store, :index?)

      @query = Admin::StoreQuery.new(filter_params)
      @pagy, @stores = pagy(@query.call, limit: pagination_limit)
    end

    def show
      authorize_admin!(@store, :show?)

      @listings = @store.listings.includes(:category).order(created_at: :desc).limit(10)
      @orders = @store.orders.includes(:buyer).order(created_at: :desc).limit(10)
      @reviews = @store.reviews.includes(:reviewer).order(created_at: :desc).limit(5)
      @audit_logs = AdminAuditLog.where(auditable: @store).includes(:admin).recent.limit(20)
    end

    def edit
      authorize_admin!(@store, :update?)
    end

    def update
      authorize_admin!(@store, :update?)

      if @store.update(store_params)
        audit!("store.updated", @store)
        redirect_to admin_store_path(@store), notice: t("admin.stores.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_store
      @store = Store.includes(:user, :region).friendly.find(params[:id])
    end

    def filter_params
      params.permit(:q, :verified, :store_type, :vacation, :sort, :direction)
    end

    def store_params
      params.require(:store).permit(:name, :description, :store_type, :company_name, :tax_id,
                                    :vacation_mode, :vacation_message, :return_policy,
                                    :shipping_policy, :country_code, :region_id, :city,
                                    :allow_offers_default)
    end
  end
end
