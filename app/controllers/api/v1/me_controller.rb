module Api
  module V1
    class MeController < BaseController
      before_action :authenticate!

      PROFILE_ATTRIBUTES = %i[first_name last_name phone city country_code region_id locale].freeze

      def show
        @user = current_user
        render :show, formats: :json
      end

      def update
        attributes = params.permit(*PROFILE_ATTRIBUTES).to_h
        if attributes["locale"].present?
          attributes.delete("locale") unless I18n.available_locales.map(&:to_s).include?(attributes["locale"].to_s)
        end

        current_user.update!(attributes)

        if params[:notification_preferences].present?
          preferences = params.permit(notification_preferences: User::NOTIFICATION_EMAIL_KEYS)
                                .fetch(:notification_preferences, {})
          current_user.update_notification_preferences!(preferences)
        end

        @user = current_user.reload
        render :show, formats: :json
      end

      def destroy
        current_user.soft_delete!
        current_api_token&.destroy!
        head :no_content
      end

      def export
        @payload = UserDataExport.new(current_user).as_json
        render :export, formats: :json
      end
    end
  end
end
