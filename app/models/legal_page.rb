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

  private

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
