module Admin
  class SettingsController < BaseController
    def index
      authorize_admin!(Setting, :index?)

      @values = Setting::DEFAULTS.merge(Setting.cached_values)
      @groups = Setting::GROUPS
    end

    def update
      authorize_admin!(Setting, :update?)

      changes = Admin::SettingsUpdater.new(settings_params).call
      if changes.any?
        audit!("settings.updated", Setting.first || Setting.new,
               changeset: changes.to_h { |key, old, new| [ key, [ old, new ] ] })
        redirect_to admin_settings_path, notice: t("admin.settings.updated")
      else
        redirect_to admin_settings_path, notice: t("admin.settings.unchanged")
      end
    end

    private

    def settings_params
      params.fetch(:settings, {}).permit(*Setting::DEFAULTS.keys)
    end
  end
end
