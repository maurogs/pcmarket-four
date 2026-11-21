module Admin
  class StoreQuery
    SORTS = {
      "created_at" => "stores.created_at",
      "name" => "stores.name",
      "rating_avg" => "stores.rating_avg",
      "sales_count" => "stores.sales_count",
      "listings_count" => "stores.listings_count"
    }.freeze

    def initialize(params = {})
      @params = params.to_h.with_indifferent_access
    end

    def call
      scope = Store.includes(:user, :region)
      query = @params[:q].to_s.strip
      if query.present?
        pattern = "%#{Store.sanitize_sql_like(query)}%"
        scope = scope.where("stores.name ILIKE :q OR users.email ILIKE :q", q: pattern).joins(:user)
      end
      scope = scope.where(verified: true) if @params[:verified].to_s == "yes"
      scope = scope.where(verified: false) if @params[:verified].to_s == "no"
      if Store.store_types.key?(@params[:store_type].to_s)
        scope = scope.where(store_type: @params[:store_type])
      end
      scope = scope.where(vacation_mode: true) if @params[:vacation].to_s == "yes"
      scope.order(Arel.sql("#{sort} #{direction}")).order(id: :desc)
    end

    private

    def sort
      SORTS.fetch(@params[:sort].to_s, "stores.created_at")
    end

    def direction
      %w[asc desc].include?(@params[:direction].to_s) ? @params[:direction] : "desc"
    end
  end
end
