# Notification preferences: /:locale/account/notifications/edit. One checkbox
# per User::NOTIFICATION_KEYS plus the marketing opt-in (timestamped in the
# model). Unchecked boxes arrive as "0" and are cast to real booleans so the
# jsonb map stays clean.
module Account
  class NotificationsController < ApplicationController
    before_action :authenticate_user!

    def edit; end

    def update
      if current_user.update(notification_params)
        redirect_to edit_account_notifications_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def notification_params
      permitted = params.expect(user: [ { notification_preferences: User::NOTIFICATION_KEYS },
                                        :marketing_opt_in ])
      boolean = ActiveModel::Type::Boolean.new
      raw = permitted.fetch(:notification_preferences, {})
      preferences = User::NOTIFICATION_KEYS.index_with { |key| boolean.cast(raw[key]) }
      { notification_preferences: preferences, marketing_opt_in: boolean.cast(permitted[:marketing_opt_in]) }
    end
  end
end
