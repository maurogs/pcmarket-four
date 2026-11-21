module Notifications
  class ReadAllsController < ApplicationController
    before_action :authenticate_user!

    def create
      current_user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)
      redirect_to notifications_path, notice: t("notifications.read_all.done"), status: :see_other
    end
  end
end
