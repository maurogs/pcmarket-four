class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = current_user.notifications.order(Arel.sql("read_at IS NULL DESC"), created_at: :desc)
    @pagy, @notifications = pagy(scope, limit: 20)
    @unread_count = current_user.notifications.unread.count
    @menu = params[:menu].present?
    render partial: "notifications/menu", layout: false if @menu
  end

  def update
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!
    redirect_to notification.url.presence || notifications_path, status: :see_other
  end
end
