class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  include PgSearch::Model

  # Looks up a translated label for an enum value, falling back to a humanised
  # version of the raw value when the translation is missing.
  def self.human_enum(attribute, value)
    return nil if value.blank?

    I18n.t(
      "activerecord.enums.#{model_name.i18n_key}.#{attribute}.#{value}",
      default: value.to_s.humanize
    )
  end
end
