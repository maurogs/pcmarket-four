module Admin
  # Builds the filtered, sorted listing relation used by the admin listing
  # table. Only whitelisted sort keys reach the SQL ORDER BY clause.
  class ListingQuery
    SORTS = {
      "created_at" => "listings.created_at",
      "updated_at" => "listings.updated_at",
      "published_at" => "listings.published_at",
      "price_cents" => "listings.price_cents",
      "title" => "listings.title",
      "status" => "listings.status",
      "views_count" => "listings.views_count",
      "favorites_count" => "listings.favorites_count"
    }.freeze

    DEFAULT_SORT = "created_at".freeze
    DIRECTIONS = %w[asc desc].freeze

    def initialize(params = {})
      @params = params.to_h.with_indifferent_access
    end

    def call
      scope = base_scope
      scope = filter_query(scope)
      scope = filter_status(scope)
      scope = filter_category(scope)
      scope = filter_seller(scope)
      scope = filter_country(scope)
      scope = filter_price(scope)
      scope = filter_labels(scope)
      scope = filter_featured(scope)
      scope = filter_flagged(scope)
      scope = filter_created(scope)
      order(scope)
    end

    def sort
      key = @params[:sort].to_s
      SORTS.key?(key) ? key : DEFAULT_SORT
    end

    def direction
      DIRECTIONS.include?(@params[:direction].to_s) ? @params[:direction].to_s : "desc"
    end

    private

    attr_reader :params

    def base_scope
      Listing.includes(:user, :store, :category, images_attachments: :blob)
    end

    def filter_query(scope)
      query = params[:q].to_s.strip
      return scope if query.blank?

      pattern = "%#{Listing.sanitize_sql_like(query)}%"
      if query.match?(/\A\d+\z/)
        scope.where("listings.title ILIKE :q OR listings.id = :id", q: pattern, id: query.to_i)
      else
        scope.where("listings.title ILIKE :q", q: pattern)
      end
    end

    def filter_status(scope)
      status = params[:status].to_s
      Listing.statuses.key?(status) ? scope.where(status: status) : scope
    end

    def filter_category(scope)
      category_id = params[:category_id].presence
      return scope if category_id.blank?

      category = Category.find_by(id: category_id)
      category ? scope.in_category(category) : scope.none
    end

    def filter_seller(scope)
      seller = params[:seller].to_s.strip
      return scope if seller.blank?

      pattern = "%#{Listing.sanitize_sql_like(seller)}%"
      scope.joins(:user).where(
        "users.username ILIKE :q OR users.email ILIKE :q OR users.id = :id",
        q: pattern, id: seller.to_i
      )
    end

    def filter_country(scope)
      country = params[:country].to_s.upcase
      country.match?(/\A[A-Z]{2}\z/) ? scope.where(country_code: country) : scope
    end

    def filter_price(scope)
      scope = scope.where("listings.price_cents >= ?", cents(params[:min_price])) if params[:min_price].present?
      scope = scope.where("listings.price_cents <= ?", cents(params[:max_price])) if params[:max_price].present?
      scope
    end

    def cents(value)
      Listing.parse_price_cents(value).to_i
    end

    def filter_labels(scope)
      labels = Array(params[:labels]).map(&:to_s) & Listing::LABELS
      return scope if labels.empty?

      labels.each do |label|
        scope = scope.where("? = ANY(listings.labels)", label)
      end
      scope
    end

    def filter_featured(scope)
      case params[:featured].to_s
      when "yes" then scope.featured
      when "no" then scope.where("listings.featured_until IS NULL OR listings.featured_until <= ?", Time.current)
      else scope
      end
    end

    def filter_flagged(scope)
      ActiveModel::Type::Boolean.new.cast(params[:flagged]) ? scope.where(status: :pending_review) : scope
    end

    def filter_created(scope)
      scope = scope.where("listings.created_at >= ?", parse_date(params[:created_from]).beginning_of_day) if params[:created_from].present?
      scope = scope.where("listings.created_at <= ?", parse_date(params[:created_to]).end_of_day) if params[:created_to].present?
      scope
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue Date::Error, ArgumentError
      Date.current
    end

    def order(scope)
      scope.order(Arel.sql("#{SORTS.fetch(sort)} #{direction.upcase}")).order(id: :desc)
    end
  end
end
