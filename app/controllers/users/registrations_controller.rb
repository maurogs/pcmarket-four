module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :ensure_registrations_enabled, only: %i[new create]

    protected

    def build_resource(hash = {})
      super
      resource.terms_required = true
      resource.country_code = "ES" if resource.country_code.blank?
      resource.locale = I18n.locale.to_s
      resource.accepts_marketing = ActiveModel::Type::Boolean.new.cast(params.dig(:user, :accepts_marketing)) == true
    end

    private

    def ensure_registrations_enabled
      return if Setting.enabled?("registrations_enabled")

      redirect_to new_user_session_path, alert: t("auth.registrations_disabled")
    end
  end
end
