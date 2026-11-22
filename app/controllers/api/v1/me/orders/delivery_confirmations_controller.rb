module Api
  module V1
    module Me
      module Orders
        class DeliveryConfirmationsController < BaseController
          before_action :authenticate!

          def create
            @order = buyer_order
            authorize @order, :delivery_confirmation?

            unless @order.confirm_delivery!(current_user)
              return render_error("order_action_failed", t("api.errors.order_action_failed"),
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
