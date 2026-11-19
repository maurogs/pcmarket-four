# Locale accessors for jsonb `*_translations` columns shaped like
# { "en" => "Graphics Cards", "es" => "Tarjetas gráficas", … }.
#
# `translated_fields :name, :description` defines `name` / `description`
# readers (current `I18n.locale`, falling back to English) and
# `name_for(:de)` style lookups.
module Translatable
  extend ActiveSupport::Concern

  FALLBACK_LOCALE = "en".freeze

  class_methods do
    def translated_fields(*fields)
      fields.each do |field|
        column = "#{field}_translations"

        define_method(field) do
          translation_for(column)
        end

        define_method("#{field}_for") do |locale|
          translation_for(column, locale)
        end
      end
    end
  end

  def translation_for(column, locale = I18n.locale)
    translations = self[column].presence || {}
    translations[locale.to_s] || translations[FALLBACK_LOCALE]
  end
end
