module Api
  module V1
    module Me
      module Orders
        class ReviewsController < BaseController
          before_action :authenticate!

          def create
            unless Setting.enabled?("reviews_enabled")
              return render_error("forbidden", t("api.errors.forbidden"), status: :forbidden)
            end

            order = current_user.orders_as_buyer.find_by!(number: params[:order_number])
            authorize order, :review?

            review = order.build_review(
              reviewer: current_user,
              store: order.store,
              rating: params[:rating],
              body: params[:body]
            )

            if review.save
              @review = review
              render :create, formats: :json, status: :created
            else
              render_error("validation_failed", t("api.errors.validation_failed"),
                           status: :unprocessable_entity,
                           details: review.errors.to_hash.transform_values { |messages| Array(messages) })
            end
          end
        end
      end
    end
  end
end
