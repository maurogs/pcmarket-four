class FilterOption < ApplicationRecord
  belongs_to :filter_definition, inverse_of: :filter_options

  validates :value, presence: true, uniqueness: { scope: :filter_definition_id, case_sensitive: false }

  after_commit { ListingSearch.bust_caches! }

  def label(locale = I18n.locale)
    labels[locale.to_s].presence || labels["es"].presence || labels["en"].presence || value
  end

  def to_s
    label
  end
end
