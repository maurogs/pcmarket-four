module Admin
  # Resolves or dismisses a report, applies an optional moderation action and
  # notifies the reporter of the outcome.
  class ReportResolution
    ACTIONS = %w[hide_listing suspend_user delete_review].freeze

    def self.call(admin, report, decision:, action: nil, reason: nil)
      new(admin, report, decision: decision, action: action, reason: reason).call
    end

    def initialize(admin, report, decision:, action: nil, reason: nil)
      @admin = admin
      @report = report
      @decision = decision.to_s
      @action = action.to_s
      @reason = reason.to_s
    end

    def call
      case @decision
      when "dismiss"
        @report.dismiss!(@admin)
        notify_reporter
        true
      when "resolve"
        apply_action
        @report.resolve!(@admin)
        notify_reporter
        true
      else
        false
      end
    end

    private

    def apply_action
      return unless ACTIONS.include?(@action)

      case @action
      when "hide_listing" then hide_listing
      when "suspend_user" then suspend_user
      when "delete_review" then delete_review
      end
    end

    def hide_listing
      listing = @report.reportable
      listing.pause! if listing.is_a?(Listing) && listing.published?
    end

    def suspend_user
      user = @report.reportable
      Admin::UserModeration.suspend(user, reason: @reason.presence || "reported") if user.is_a?(User)
    end

    def delete_review
      review = @report.reportable
      review.update!(published: false) if review.is_a?(Review)
    end

    def notify_reporter
      target = I18n.t("admin.reports.types.#{@report.reportable_type.underscore}",
                      default: @report.reportable_type)
      Notifier.call(
        @report.reporter,
        kind,
        params: { reportable: target, report_id: @report.id },
        url: Rails.application.routes.url_helpers.admin_reports_path(locale: @report.reporter.locale)
      )
    end

    def kind
      @decision == "dismiss" ? "report_dismissed" : "report_resolved"
    end
  end
end
