module Orders
  class ReviewsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_reviews_enabled

    def new
      @order = current_user.orders_as_buyer.find_by!(number: params[:order_number])
      authorize @order, :review?
      @review = @order.build_review
    end

    def create
      @order = current_user.orders_as_buyer.find_by!(number: params[:order_number])
      authorize @order, :review?
      @review = @order.build_review(
        reviewer: current_user,
        store: @order.store,
        rating: params.dig(:review, :rating),
        body: params.dig(:review, :body)
      )

      if @review.save
        redirect_to order_path(@order), notice: t("orders.reviews.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def ensure_reviews_enabled
      return if Setting.enabled?("reviews_enabled")

      redirect_to orders_path, alert: t("orders.reviews.disabled")
    end
  end
end
