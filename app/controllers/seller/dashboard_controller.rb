module Seller
  class DashboardController < BaseController
    def show
      @dashboard = SellerDashboard.new(seller_store).call
    end
  end
end
