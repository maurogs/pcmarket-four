# Cached accessor for application settings, backed by the Setting model.
# Values are cached in Rails.cache and invalidated by Setting's after_commit
# callback, so reads are essentially free.
module AppSettings
  module_function

  def get(key, default = nil)
    entry = Rails.cache.fetch("app_settings/#{key}") do
      setting = Setting.find_by(key: key.to_s)
      setting && { "value" => setting.typed_value }
    end

    if entry.is_a?(Hash) && entry.key?("value")
      entry["value"]
    else
      default
    end
  end

  def enabled?(key)
    ActiveModel::Type::Boolean.new.cast(get(key, false))
  end

  # Localized string from a jsonb hash like { "en" => "...", "es" => "..." }.
  def localized(key, locale = I18n.locale)
    value = get(key)
    return nil unless value.is_a?(Hash)

    value[locale.to_s] || value["en"]
  end

  # Every setting as a key => typed_value hash (cached).
  def all
    Rails.cache.fetch(Setting.cache_key_for_all) do
      Setting.all.index_by(&:key).transform_values(&:typed_value)
    end
  end
end
