module Api
  module V1
    module Me
      class SalesController < BaseController
        before_action :authenticate!

        def index
          filter = params[:status].presence || "to_ship"
          filter = "to_ship" unless Order::SELLER_FILTERS.key?(filter)
          scope = Order.seller_orders(current_user, filter: filter, query: params[:q])
          @orders, @pagy = paginate(scope)
          render :index, formats: :json
        end

        def show
          @order = seller_order
          render :show, formats: :json
        end

        private

        def seller_order
          current_user.orders_as_seller
                      .includes(:store, :seller, :buyer, :review,
                                order_items: { listing: { images_attachments: :blob } },
                                order_events: [])
                      .find_by!(number: params[:number])
        end
      end
    end
  end
end
