module Admin
  # Filtered user directory for the admin panel and the CSV export.
  class UserQuery
    SORTS = {
      "created_at" => "users.created_at",
      "last_sign_in_at" => "users.last_sign_in_at",
      "username" => "users.username",
      "email" => "users.email",
      "role" => "users.role",
      "status" => "users.status",
      "sign_in_count" => "users.sign_in_count"
    }.freeze
    DEFAULT_SORT = "created_at".freeze

    def initialize(params = {})
      @params = params.to_h.with_indifferent_access
    end

    def call
      scope = User.includes(:store, :country)
      scope = filter_query(scope)
      scope = filter_role(scope)
      scope = filter_status(scope)
      scope = filter_confirmed(scope)
      scope = filter_store(scope)
      scope = filter_country(scope)
      scope = filter_dates(scope)
      order(scope)
    end

    def sort
      key = @params[:sort].to_s
      SORTS.key?(key) ? key : DEFAULT_SORT
    end

    def direction
      %w[asc desc].include?(@params[:direction].to_s) ? @params[:direction].to_s : "desc"
    end

    private

    attr_reader :params

    def filter_query(scope)
      query = params[:q].to_s.strip
      return scope if query.blank?

      pattern = "%#{User.sanitize_sql_like(query)}%"
      scope.where(
        "users.email ILIKE :q OR users.username ILIKE :q OR users.first_name ILIKE :q OR users.last_name ILIKE :q",
        q: pattern
      )
    end

    def filter_role(scope)
      role = params[:role].to_s
      User.roles.key?(role) ? scope.where(role: role) : scope
    end

    def filter_status(scope)
      status = params[:status].to_s
      User.statuses.key?(status) ? scope.where(status: status) : scope
    end

    def filter_confirmed(scope)
      case params[:confirmed].to_s
      when "yes" then scope.where.not(confirmed_at: nil)
      when "no" then scope.where(confirmed_at: nil)
      else scope
      end
    end

    def filter_store(scope)
      case params[:has_store].to_s
      when "yes" then scope.where(id: Store.select(:user_id))
      when "no" then scope.where.not(id: Store.select(:user_id))
      else scope
      end
    end

    def filter_country(scope)
      country = params[:country].to_s.upcase
      country.match?(/\A[A-Z]{2}\z/) ? scope.where(country_code: country) : scope
    end

    def filter_dates(scope)
      if params[:signed_up_from].present?
        scope = scope.where("users.created_at >= ?", parse_date(params[:signed_up_from]).beginning_of_day)
      end
      if params[:signed_up_to].present?
        scope = scope.where("users.created_at <= ?", parse_date(params[:signed_up_to]).end_of_day)
      end
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
