module Admin
  # Computes the live launch checklist for enabling a country. The checks are
  # read-only; the controller decides whether enabling is blocked.
  class CountryLaunchChecklist
    LEGAL_SLUGS = %w[
      terms privacy cookies legal_notice returns buyer_protection seller_terms
      prohibited_items
    ].freeze

    Check = Struct.new(:key, :passed, :detail, keyword_init: true)

    def initialize(country)
      @country = country
    end

    def checks
      [ legal_pages_check, english_legal_pages_check, regions_check, currency_check ]
    end

    def ready?
      checks.all?(&:passed)
    end

    def blocked_reason
      return nil if currency_check.passed

      "currency"
    end

    private

    def legal_pages_check
      missing = missing_slugs(@country.default_locale)
      Check.new(key: "legal_pages", passed: missing.empty?, detail: missing)
    end

    def english_legal_pages_check
      missing = missing_slugs("en")
      Check.new(key: "legal_pages_en", passed: missing.empty?, detail: missing)
    end

    def regions_check
      count = Region.where(country_code: @country.code).count
      Check.new(key: "regions", passed: count.positive?, detail: count)
    end

    def currency_check
      supported = @country.currency == "EUR" || Setting.enabled?("allow_non_eur_countries")
      Check.new(key: "currency", passed: supported, detail: @country.currency)
    end

    def missing_slugs(locale)
      published = LegalPage.published.where(country_code: @country.code, locale: locale)
                           .pluck(:slug)
      LEGAL_SLUGS - published
    end
  end
end
