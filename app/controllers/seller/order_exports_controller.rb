module Seller
  class OrderExportsController < BaseController
    def create
      filter = Order::SELLER_FILTERS.key?(params[:filter]) ? params[:filter] : "to_ship"
      csv = SellerOrderExport.new(current_user, filter: filter, query: params[:q].to_s).call
      send_data csv,
                filename: "orders-#{Date.current.iso8601}.csv",
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end
  end
end
