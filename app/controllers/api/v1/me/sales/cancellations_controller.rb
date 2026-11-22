module Api
  module V1
    module Me
      module Sales
        class CancellationsController < BaseController
          before_action :authenticate!

          def create
            order = seller_order
            reason = params[:reason].presence || "seller_cancelled"
            refund_required = params.key?(:refund_required) ?
              ActiveModel::Type::Boolean.new.cast(params[:refund_required]) : nil

            unless order.cancel!(current_user, reason, refund_required: refund_required)
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
