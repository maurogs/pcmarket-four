# Static reference data for Spanish provinces (see config/spanish_provinces.yml).
# Backs the `province` code on Store and Listing; names are localized.
class SpanishProvince
  CONFIG = Rails.root.join("config/spanish_provinces.yml")

  Record = Struct.new(:code, :key) do
    def name(locale: I18n.locale)
      I18n.t("spanish_provinces.#{key}", locale: locale, default: code)
    end
  end

  class << self
    def all
      @all ||= begin
        data = YAML.load_file(CONFIG).fetch("PROVINCES")
        data.map { |row| Record.new(row.fetch("code").to_s, row.fetch("key").to_s) }
      end
    end

    def codes
      all.map(&:code)
    end

    def find(code)
      all.find { |province| province.code == code.to_s }
    end

    def name(code, locale: I18n.locale)
      record = find(code)
      record ? record.name(locale: locale) : code.to_s
    end

    # For select tags: [[name, code], …] sorted by translated name.
    def options(locale: I18n.locale)
      all.sort_by { |province| province.name(locale: locale) }
        .map { |province| [ province.name(locale: locale), province.code ] }
    end
  end
end
