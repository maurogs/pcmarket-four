class OrdersController < ApplicationController
  before_action :authenticate_user!, except: :show

  def index
    authorize Order
    @filter = Order::FILTERS.key?(params[:filter]) ? params[:filter] : "all"
    @query = params[:q].to_s
    @orders = Order.buyer_orders(current_user, filter: @filter, query: @query)
    @counts = Order.for_buyer(current_user).group(:status).count
  end

  def show
    @order = Order.includes(:store, :seller, :order_events, :review,
                            order_items: { listing: { images_attachments: :blob } })
                  .find_by!(number: params[:number])

    if guest_token_valid?
      @guest_view = true
    else
      authenticate_user!
      authorize @order if user_signed_in?
    end
    @reviews_enabled = Setting.enabled?("reviews_enabled")
  end

  private

  def guest_token_valid?
    return false if params[:token].blank? || @order.guest_access_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(@order.guest_access_token),
      Digest::SHA256.hexdigest(params[:token].to_s)
    )
  end
end
