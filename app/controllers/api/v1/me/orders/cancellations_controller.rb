module Api
  module V1
    module Me
      module Orders
        class CancellationsController < BaseController
          before_action :authenticate!

          def create
            @order = buyer_order
            authorize @order, :cancellation?

            unless @order.cancel!(current_user, params[:reason].presence || "buyer_cancelled")
              return render_error("order_not_cancellable", t("api.errors.order_not_cancellable"),
                                  status: :conflict)
            end

            render "api/v1/me/orders/show", formats: :json
          end

          private

          def buyer_order
            current_user.orders_as_buyer
                        .includes(:store, :seller, :buyer, :review,
                                  order_items: { listing: { images_attachments: :blob } },
                                  order_events: [])
                        .find_by!(number: params[:order_number])
          end
        end
      end
    end
  end
end
