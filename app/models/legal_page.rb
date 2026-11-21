class LegalPage < ApplicationRecord
  SLUGS = %w[
    terms privacy cookies legal_notice returns buyer_protection seller_terms
    prohibited_items dsa_contact
  ].freeze

  belongs_to :updated_by, class_name: "User", optional: true, inverse_of: false

  validates :slug, presence: true, inclusion: { in: SLUGS }
  validates :title, :body, presence: true
  validates :slug, uniqueness: { scope: [ :country_code, :locale ] }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }

  scope :published, -> { where(published: true) }
  scope :for_locale, ->(locale) { where(locale: locale.to_s) }

  def to_param
    slug
  end
end
