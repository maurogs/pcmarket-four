module Admin
  # Filtered review moderation queue.
  class ReviewQuery
    SORTS = {
      "created_at" => "reviews.created_at",
      "rating" => "reviews.rating",
      "published" => "reviews.published"
    }.freeze

    def initialize(params = {})
      @params = params.to_h.with_indifferent_access
    end

    def call
      scope = Review.includes(:reviewer, :store, order: %i[buyer seller])
      scope = filter_rating(scope)
      scope = filter_published(scope)
      scope = filter_store(scope)
      scope = filter_reply(scope)
      scope = filter_created(scope)
      scope.order(Arel.sql("#{SORTS.fetch(sort)} #{direction.upcase}")).order(id: :desc)
    end

    def sort
      SORTS.key?(@params[:sort].to_s) ? @params[:sort].to_s : "created_at"
    end

    def direction
      %w[asc desc].include?(@params[:direction].to_s) ? @params[:direction].to_s : "desc"
    end

    private

    def filter_rating(scope)
      rating = @params[:rating].to_i
      (1..5).cover?(rating) ? scope.where(rating: rating) : scope
    end

    def filter_published(scope)
      case @params[:published].to_s
      when "yes" then scope.where(published: true)
      when "no" then scope.where(published: false)
      else scope
      end
    end

    def filter_store(scope)
      store = @params[:store].to_s.strip
      return scope if store.blank?

      pattern = "%#{Store.sanitize_sql_like(store)}%"
      scope.joins(:store).where("stores.name ILIKE :q OR CAST(reviews.store_id AS TEXT) = :id", q: pattern, id: store)
    end

    def filter_reply(scope)
      case @params[:has_reply].to_s
      when "yes" then scope.where.not(seller_reply: [ nil, "" ])
      when "no" then scope.where(seller_reply: [ nil, "" ])
      else scope
      end
    end

    def filter_created(scope)
      scope = scope.where("reviews.created_at >= ?", parse_date(@params[:created_from]).beginning_of_day) if @params[:created_from].present?
      scope = scope.where("reviews.created_at <= ?", parse_date(@params[:created_to]).end_of_day) if @params[:created_to].present?
      scope
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue Date::Error, ArgumentError
      Date.current
    end
  end
end
