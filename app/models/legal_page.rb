class LegalPage < ApplicationRecord
  SLUGS = %w[
    terms privacy cookies legal_notice returns buyer_protection seller_terms
    prohibited_items dsa_contact
  ].freeze

  ALLOWED_TAGS = %w[
    p br strong b em i u s ul ol li h1 h2 h3 h4 a blockquote table thead tbody tr th td
    hr small span div
  ].freeze

  ALLOWED_ATTRIBUTES = %w[href title target rel class].freeze

  PLACEHOLDER_KEYS = %w[
    company_legal_name company_tax_id company_address company_registry contact_email
    support_email dpo_email legal_email support_phone support_hours
  ].freeze

  PLACEHOLDER_PATTERN = /\{\{\s*([a-z0-9_]+)\s*\}\}/i

  belongs_to :updated_by, class_name: "User", optional: true, inverse_of: false
  belongs_to :country, foreign_key: :country_code, primary_key: :code, optional: true,
                       inverse_of: false

  validates :slug, presence: true, inclusion: { in: SLUGS }
  validates :title, :body, presence: true
  validates :slug, uniqueness: { scope: [ :country_code, :locale ] }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }

  before_save :bump_version, if: :publishing_change?

  scope :published, -> { where(published: true) }
  scope :for_locale, ->(locale) { where(locale: locale.to_s) }
  scope :for_country, ->(country_code) { where(country_code: country_code.to_s.upcase) }

  def self.resolve(country:, locale:, slug:)
    return nil if country.nil?

    scope = published.for_country(country.code).where(slug: slug.to_s)
    candidates = [ locale.to_s, country.default_locale.to_s, "en" ].reject(&:blank?).uniq
    candidates.each do |candidate|
      page = scope.find_by(locale: candidate)
      return page if page
    end
    nil
  end

  def self.available_locales_for(country_code:, slug:)
    published.for_country(country_code).where(slug: slug.to_s).distinct.pluck(:locale)
  end

  def to_param
    slug
  end

  def body_html
    ActionController::Base.helpers.sanitize(
      body,
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )
  end

  def rendered_body
    @rendered_body ||= begin
      fragment = Nokogiri::HTML::DocumentFragment.parse(interpolated_body)
      fragment.css("h2").each_with_index do |heading, index|
        heading["id"] = heading_id(heading.text, index) if heading["id"].blank?
      end
      fragment.to_html.html_safe
    end
  end

  def toc
    @toc ||= begin
      fragment = Nokogiri::HTML::DocumentFragment.parse(rendered_body.to_s)
      fragment.css("h2").each_with_index.map do |heading, index|
        { id: heading["id"].presence || "section-#{index + 1}", title: heading.text.squish }
      end
    end
  end

  private

  def interpolated_body
    body_html.gsub(PLACEHOLDER_PATTERN) do
      key = Regexp.last_match(1).to_s
      next "" unless PLACEHOLDER_KEYS.include?(key)

      ERB::Util.html_escape(Setting.get(key, "").to_s)
    end
  end

  def heading_id(text, index)
    base = text.to_s.parameterize.presence || "section-#{index + 1}"
    "#{base}-#{index + 1}"
  end

  def publishing_change?
    return false unless persisted?

    (will_save_change_to_published? && published?) ||
      will_save_change_to_body? || will_save_change_to_title?
  end

  def bump_version
    self.version = [ version.to_i, 1 ].max + 1
    self.published_at = Time.current if will_save_change_to_published? && published?
  end
end
