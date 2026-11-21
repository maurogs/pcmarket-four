module Seller
  class OrdersController < BaseController
    def index
      @orders = current_user.orders_as_seller.includes(:buyer, :store)
                            .order(created_at: :desc).limit(50)
    end
  end
end
