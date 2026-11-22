module Api
  module V1
    class NotificationsController < BaseController
      before_action :authenticate!

      def index
        scope = current_user.notifications.order(Arel.sql("read_at IS NULL DESC"), created_at: :desc)
        @notifications, @pagy = paginate(scope, default: 20)
        render :index, formats: :json
      end

      def update
        @notification = current_user.notifications.find(params[:id])
        @notification.mark_read!
        render :show, formats: :json
      end
    end
  end
end
