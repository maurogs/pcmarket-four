class HelpArticle < ApplicationRecord
  CATEGORIES = %w[buying selling shipping payments account safety].freeze

  enum :category, CATEGORIES.each_with_index.to_h { |name, index| [ name, index ] }

  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/ }
  validates :category, presence: true
  validate :content_present

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :id) }

  def title(locale = I18n.locale)
    titles[locale.to_s].presence || titles["es"].presence || titles["en"].presence
  end

  def body(locale = I18n.locale)
    bodies[locale.to_s].presence || bodies["es"].presence || bodies["en"].presence
  end

  def to_param
    slug
  end

  private

  def content_present
    return if titles.is_a?(Hash) && (titles["es"].present? || titles["en"].present?)
    return if bodies.is_a?(Hash) && (bodies["es"].present? || bodies["en"].present?)

    errors.add(:titles, :blank)
  end
end
