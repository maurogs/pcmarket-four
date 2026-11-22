module Api
  module V1
    module Me
      class OrdersController < BaseController
        before_action :authenticate!

        def index
          filter = params[:status].presence || "all"
          filter = "all" unless Order::FILTERS.key?(filter)
          scope = Order.buyer_orders(current_user, filter: filter, query: params[:q])
          @orders, @pagy = paginate(scope)
          render :index, formats: :json
        end

        def show
          @order = current_user.orders_as_buyer
                              .includes(:store, :seller, :buyer, :review,
                                        order_items: { listing: { images_attachments: :blob } },
                                        order_events: [])
                              .find_by!(number: params[:number])
          authorize @order, :show?
          render :show, formats: :json
        end
      end
    end
  end
end
