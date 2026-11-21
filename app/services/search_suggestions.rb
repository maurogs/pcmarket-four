class SearchSuggestions
  LIMIT_LISTINGS = 6
  LIMIT_CATEGORIES = 3
  LIMIT_STORES = 3

  Result = Data.define(:listings, :categories, :stores, :query) do
    def empty?
      listings.empty? && categories.empty? && stores.empty?
    end
  end

  def initialize(locale: I18n.locale)
    @locale = locale.to_s
  end

  def call(query)
    term = query.to_s.strip
    return Result.new([], [], [], term) if term.length < 2

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    Result.new(
      Listing.visible.where("listings.title ILIKE ?", pattern)
             .order(published_at: :desc)
             .limit(LIMIT_LISTINGS)
             .to_a,
      categories(pattern),
      Store.where("stores.name ILIKE ?", pattern)
           .order(:name)
           .limit(LIMIT_STORES)
           .to_a,
      term
    )
  end

  private

  def categories(pattern)
    Category.active
            .where("names ->> ? ILIKE ?", @locale, pattern)
            .order(:position, :id)
            .limit(LIMIT_CATEGORIES)
            .to_a
  end
end
