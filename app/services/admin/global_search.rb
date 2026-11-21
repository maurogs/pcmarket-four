module Admin
  # Cross-resource search used by the admin top bar.
  class GlobalSearch
    LIMIT = 10

    def initialize(query)
      @query = query.to_s.strip
    end

    def call
      return empty_result if @query.blank?

      {
        users: users,
        listings: listings,
        orders: orders,
        stores: stores
      }
    end

    def empty?
      call.values.all?(&:empty?)
    end

    private

    def pattern
      "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    end

    def numeric_id
      @query.to_i if @query.match?(/\A\d+\z/)
    end

    def users
      User.where("email ILIKE :q OR username ILIKE :q OR first_name ILIKE :q OR last_name ILIKE :q", q: pattern)
          .order(created_at: :desc).limit(LIMIT)
    end

    def listings
      scope = Listing.where("title ILIKE :q", q: pattern)
      scope = scope.or(Listing.where(id: numeric_id)) if numeric_id
      scope.includes(:user, :store, :category).order(created_at: :desc).limit(LIMIT)
    end

    def orders
      scope = Order.where("number ILIKE :q", q: pattern)
      scope = scope.or(Order.where(id: numeric_id)) if numeric_id
      scope.includes(:buyer, :seller, :store).order(created_at: :desc).limit(LIMIT)
    end

    def stores
      Store.where("name ILIKE :q", q: pattern)
           .includes(:user).order(created_at: :desc).limit(LIMIT)
    end

    def empty_result
      { users: User.none, listings: Listing.none, orders: Order.none, stores: Store.none }
    end
  end
end
