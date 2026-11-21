module Checkout
  class ConfirmationsController < ApplicationController
    def show
      ids = Array(session.delete(:checkout_order_ids))
      session.delete(:checkout_token)
      buyer_scope = current_user ? Order.where(buyer_id: current_user.id) : Order.where(buyer_id: nil)
      @orders = buyer_scope.where(id: ids).includes(:store, :seller, :order_items).order(:id).to_a

      if @orders.empty?
        redirect_to cart_path, alert: t("checkout.errors.empty_cart")
        return
      end

      @order = @orders.first
      @payment_method = @order.payment_method
      @total_cents = @orders.sum(&:total_cents)
    end
  end
end
