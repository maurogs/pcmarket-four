module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show edit update]

    def index
      authorize_admin!(User, :index?)

      @query = Admin::UserQuery.new(filter_params)
      @pagy, @users = pagy(@query.call, limit: pagination_limit)
    end

    def show
      authorize_admin!(@user, :show?)

      @listings = @user.listings.includes(:category).order(created_at: :desc).limit(10)
      @audit_logs = AdminAuditLog.where(auditable: @user).includes(:admin).recent.limit(20)
      @stats = {
        listings: @user.listings.count,
        buyer_orders: @user.orders_as_buyer.count,
        seller_orders: @user.orders_as_seller.count,
        gmv_cents: @user.orders_as_seller.where(status: Admin::Dashboard::PAID_STATUSES).sum(:total_cents),
        reviews: Review.where(store_id: @user.store&.id).count,
        reports: Report.where(reportable_type: "Listing", reportable_id: @user.listings.select(:id)).count
      }
    end

    def edit
      authorize_admin!(@user, :update?)
    end

    def update
      authorize_admin!(@user, :update?)

      if @user.update(user_params)
        audit!("user.updated", @user)
        redirect_to admin_user_path(@user), notice: t("admin.users.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.includes(:store, :country).find(params[:id])
    end

    def filter_params
      params.permit(:q, :role, :status, :confirmed, :has_store, :country,
                    :signed_up_from, :signed_up_to, :sort, :direction)
    end

    def user_params
      params.require(:user).permit(:username, :email, :first_name, :last_name, :phone,
                                   :country_code, :region_id, :city, :locale)
    end
  end
end
