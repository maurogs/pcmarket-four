# Seller dashboard: /:locale/seller/dashboard. Every number comes from the
# Seller::Dashboard service (aggregate queries, memoized per request) — the
# controller stays skinny. Sellers without a store are bounced to the store
# opening flow: the dashboard has nothing to show until a store exists.
module Seller
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :redirect_to_open_store

    def show
      @dashboard = Seller::Dashboard.new(current_user.store, period: params[:period])
    end

    private

    # No store yet — send the seller through "open your store" first.
    def redirect_to_open_store
      redirect_to new_seller_store_path unless current_user.store
    end
  end
end
