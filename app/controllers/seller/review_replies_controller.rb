module Seller
  class ReviewRepliesController < BaseController
    def create
      review = seller_review
      return redirect_to fallback_path, alert: t("seller.reviews.already_replied") if review.replied?

      save_reply(review)
    end

    def update
      save_reply(seller_review)
    end

    private

    def save_reply(review)
      if review.update(seller_reply: params.dig(:review, :seller_reply))
        redirect_to fallback_path, notice: t("seller.reviews.reply_saved")
      else
        redirect_to fallback_path, alert: review.errors.full_messages.to_sentence
      end
    end

    def seller_review
      seller_store.reviews.find(params[:review_id])
    end

    def fallback_path
      order = seller_review.order
      order ? seller_order_path(order) : store_path(seller_store, tab: "reviews")
    end
  end
end
