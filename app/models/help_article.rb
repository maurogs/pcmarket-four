class HelpArticle < ApplicationRecord
  CATEGORIES = %w[buying selling shipping payments account safety].freeze

  enum :category, CATEGORIES.each_with_index.to_h { |name, index| [ name, index ] }

  has_many :help_article_feedbacks, dependent: :destroy, inverse_of: :help_article

  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/ }
  validates :category, presence: true
  validate :content_present

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :for_category, ->(category) { where(category: category) }

  def self.search(query, locale: I18n.locale)
    term = query.to_s.squish
    return published if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    published.where(
      "unaccent(titles ->> ?) ILIKE unaccent(?) OR unaccent(bodies ->> ?) ILIKE unaccent(?)",
      locale.to_s, pattern, locale.to_s, pattern
    )
  end

  def self.popular(limit = 6)
    published
      .left_joins(:help_article_feedbacks)
      .group("help_articles.id")
      .order(Arel.sql("COUNT(help_article_feedbacks.id) DESC"), :position, :id)
      .limit(limit)
  end

  def title(locale = I18n.locale)
    titles[locale.to_s].presence || titles["es"].presence || titles["en"].presence
  end

  def body(locale = I18n.locale)
    bodies[locale.to_s].presence || bodies["es"].presence || bodies["en"].presence
  end

  def body_html(locale = I18n.locale)
    ActionController::Base.helpers.sanitize(
      body(locale).to_s,
      tags: LegalPage::ALLOWED_TAGS,
      attributes: LegalPage::ALLOWED_ATTRIBUTES
    )
  end

  def helpful_count
    help_article_feedbacks.helpful.count
  end

  def unhelpful_count
    help_article_feedbacks.unhelpful.count
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
