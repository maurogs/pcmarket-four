module Admin
  # Applies a partial settings form, casting every value through Setting's
  # declared type and returning the old/new pairs for the audit log.
  class SettingsUpdater
    def initialize(params)
      @params = params.respond_to?(:to_h) ? params.to_h : {}
    end

    def call
      changes = []
      Setting.transaction do
        Setting::DEFAULTS.each_key do |key|
          next unless @params.key?(key)

          old_value = Setting.get(key)
          new_value = Setting.cast(key, @params[key])
          next if old_value.to_s == new_value.to_s

          Setting.set(key, new_value)
          changes << [ key, old_value, new_value ]
        end
      end
      changes
    end
  end
end
