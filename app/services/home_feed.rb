class HomeFeed
  ATTACHMENTS = [
    :store, :user, :category, :region,
    { images_attachments: { blob: { variant_records: { image_attachment: :blob } } } }
  ].freeze

  def initialize(locale: I18n.locale)
    @locale = locale
  end

  def hero
    @hero ||= begin
      featured = base.where("listings.featured_until > ?", Time.current)
      discounted = base.on_sale
      merged = Listing.where(id: featured.select(:id))
                      .or(Listing.where(id: discounted.select(:id)))
      with_details(merged).recent.limit(6).to_a
    end
  end

  def latest_gpus
    @latest_gpus ||= in_category("gpus").recent.limit(10).to_a
  end

  def most_watched
    @most_watched ||= base.order(favorites_count: :desc, views_count: :desc)
                          .limit(10).to_a
  end

  def on_sale
    @on_sale ||= base.on_sale.recent.limit(10).to_a
  end

  def newest
    @newest ||= base.recent.limit(10).to_a
  end

  def recently_sold
    @recently_sold ||= with_details(Listing.recently_sold).limit(10).to_a
  end

  def reviews
    @reviews ||= Review.where(published: true, rating: 5)
                       .includes(:store, reviewer: :store)
                       .order(created_at: :desc)
                       .limit(8)
                       .to_a
  end

  def promo_count(category_slug)
    in_category(category_slug).count
  end

  private

  def base
    @base ||= with_details(Listing.visible)
  end

  def in_category(slug)
    category = Category.find_by(slug: slug)
    return Listing.none if category.nil?

    base.merge(Listing.in_category(category))
  end

  def with_details(scope)
    scope.includes(*ATTACHMENTS)
  end
end
