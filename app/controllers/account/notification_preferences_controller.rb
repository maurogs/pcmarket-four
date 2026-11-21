module Account
  class NotificationPreferencesController < BaseController
    def edit
      @preferences = current_user
    end

    def update
      attributes = params.fetch(:notification_preferences, {})
                         .permit(*(User::NOTIFICATION_EMAIL_KEYS + [ "email_newsletter" ]))
                         .to_h
      current_user.update_notification_preferences!(attributes)
      redirect_to edit_account_notification_preferences_path,
                  notice: t("account.notifications.saved")
    end
  end
end
