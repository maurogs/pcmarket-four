module Admin
  # Filtered report queue for listings, users and conversations.
  class ReportQuery
    REPORTABLE_TYPES = %w[Listing User Conversation Review].freeze
    SORTS = {
      "created_at" => "reports.created_at",
      "status" => "reports.status",
      "reason" => "reports.reason"
    }.freeze

    def initialize(params = {})
      @params = params.to_h.with_indifferent_access
    end

    def call
      scope = Report.includes(:reporter, :resolved_by, :reportable)
      scope = filter_status(scope)
      scope = filter_reason(scope)
      scope = filter_reportable_type(scope)
      scope.order(Arel.sql("reports.status ASC, #{SORTS.fetch(sort)} #{direction.upcase}")).order(id: :desc)
    end

    def sort
      SORTS.key?(@params[:sort].to_s) ? @params[:sort].to_s : "created_at"
    end

    def direction
      %w[asc desc].include?(@params[:direction].to_s) ? @params[:direction].to_s : "desc"
    end

    def counts
      Report.group(:status).count
    end

    private

    def filter_status(scope)
      status = @params[:status].to_s
      Report.statuses.key?(status) ? scope.where(status: status) : scope
    end

    def filter_reason(scope)
      reason = @params[:reason].to_s
      Report.reasons.key?(reason) ? scope.where(reason: reason) : scope
    end

    def filter_reportable_type(scope)
      type = @params[:reportable_type].to_s
      REPORTABLE_TYPES.include?(type) ? scope.where(reportable_type: type) : scope
    end
  end
end
