class Country < ApplicationRecord
  has_many :regions, foreign_key: :country_code, primary_key: :code, inverse_of: :country,
                     dependent: :restrict_with_error
  has_many :users, foreign_key: :country_code, primary_key: :code, inverse_of: :country
  has_many :listings, foreign_key: :country_code, primary_key: :code, inverse_of: :country

  validates :code, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[A-Z]{2}\z/ }
  validates :name_key, presence: true
  validates :currency, presence: true

  after_commit :bust_caches

  scope :enabled, -> { where(enabled: true) }

  before_validation :normalise_code

  def name(locale = I18n.locale)
    I18n.t(name_key, locale: locale, default: code)
  end

  def to_s
    name
  end

  def bust_caches
    ListingSearch.bust_caches!
    Rails.cache.delete("country-root-slugs/v1")
  end

  private

  def normalise_code
    self.code = code.to_s.upcase if code.present?
  end
end
