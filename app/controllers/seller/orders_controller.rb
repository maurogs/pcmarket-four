module Seller
  class OrdersController < BaseController
    def index
      @filter = Order::SELLER_FILTERS.key?(params[:filter]) ? params[:filter] : "to_ship"
      @query = params[:q].to_s
      scope = Order.seller_orders(current_user, filter: @filter, query: @query)
      @pagy, @orders = pagy(scope, limit: 20)
      @counts = seller_order_counts
    end

    def show
      @order = current_user.orders_as_seller
                        .includes(:buyer, :store, :order_events, :review,
                                  order_items: { listing: { images_attachments: :blob } })
                        .find_by(number: params[:id])
      raise ActiveRecord::RecordNotFound if @order.blank?

      @reviews_enabled = Setting.enabled?("reviews_enabled")
    rescue ActiveRecord::RecordNotFound
      redirect_to seller_orders_path, alert: t("seller.orders.not_found")
    end

    private

    def seller_order_counts
      statuses = Order.where(seller_id: current_user.id).group(:status).count
      Order::SELLER_FILTERS.to_h do |key, values|
        [ key, values.sum { |status| statuses.fetch(status, 0) } ]
      end
    end
  end
end
