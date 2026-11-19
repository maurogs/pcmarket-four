class Country < ApplicationRecord
  has_many :users, dependent: :nullify

  CODES = %w[ES FR GB DE IT PT].freeze
  DEFAULT_LOCALES = %w[es en fr de it pt].freeze

  validates :code, presence: true, uniqueness: true, inclusion: { in: CODES }
  validates :name_key, presence: true
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :default_locale, presence: true, inclusion: { in: DEFAULT_LOCALES }
  validates :vat_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :launched_at, presence: true, if: :enabled?

  scope :enabled, -> { where(enabled: true) }
  scope :ordered_by_code, -> { order(:code) }

  # Countries are addressed by ISO code in URLs.
  def to_param
    code
  end

  def name
    I18n.t(name_key, default: code)
  end

  def enabled?
    enabled
  end
end
