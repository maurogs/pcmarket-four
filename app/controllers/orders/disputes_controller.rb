module Orders
  class DisputesController < ApplicationController
    before_action :authenticate_user!

    def new
      @order = current_user.orders_as_buyer.find_by!(number: params[:order_number])
      authorize @order, :dispute?
    end

    def create
      @order = current_user.orders_as_buyer.find_by!(number: params[:order_number])
      authorize @order, :dispute?

      photos = dispute_photos
      if photos.size > Order::DISPUTE_PHOTO_LIMIT
        @order.errors.add(:dispute_photos, :too_many)
        return render :new, status: :unprocessable_entity
      end

      if @order.open_dispute!(current_user, params.dig(:dispute, :reason), params.dig(:dispute, :details))
        @order.dispute_photos.attach(photos) if photos.any?
        redirect_to order_path(@order), notice: t("orders.dispute.opened")
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def dispute_photos
      Array(params.dig(:dispute, :photos)).compact_blank
    end
  end
end
