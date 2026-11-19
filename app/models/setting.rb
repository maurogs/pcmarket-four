class Setting < ApplicationRecord
  VALUE_TYPES = %w[string boolean integer float json].freeze

  validates :key, presence: true, uniqueness: true
  validates :value_type, inclusion: { in: VALUE_TYPES }

  before_validation :normalize_value

  # Invalidate the AppSettings cache whenever a setting changes.
  after_save :clear_cache
  after_touch :clear_cache
  after_destroy :clear_cache

  # Returns the value cast according to value_type.
  def typed_value
    case value_type
    when "boolean" then value.present? && value != false && value.to_s != "false"
    when "integer" then value.to_i
    when "float" then value.to_f
    else value
    end
  end

  private

  def normalize_value
    return if value.nil?

    self.value =
      case value_type
      when "boolean" then ActiveModel::Type::Boolean.new.cast(value)
      when "integer" then value.to_i
      when "float" then value.to_f
      else value
      end
  end

  def clear_cache
    Rails.cache.delete("app_settings/#{key}")
    Rails.cache.delete(Setting.cache_key_for_all)
  end

  class << self
    def cache_key_for_all
      "app_settings/all"
    end
  end
end
