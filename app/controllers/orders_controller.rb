class OrdersController < ApplicationController
  before_action :authenticate_user!

  def index
    @orders = Order
      .where("buyer_id = :id OR seller_id = :id", id: current_user.id)
      .order(created_at: :desc)
  end

  def show
    @order = Order
      .where("buyer_id = :id OR seller_id = :id", id: current_user.id)
      .find(params[:id])
  end
end
