module Api
  module V1
    module Me
      module Sales
        class PickupsController < BaseController
          before_action :authenticate!

          def create
            order = seller_order

            unless order.mark_ready_for_pickup!(current_user)
              return render_error("order_action_failed", t("api.errors.order_action_failed"),
                                  status: :conflict)
            end

            @order = order.reload
            render "api/v1/me/sales/show", formats: :json
          end

          private

          def seller_order
            current_user.orders_as_seller.find_by!(number: params[:sale_number])
          end
        end
      end
    end
  end
end
