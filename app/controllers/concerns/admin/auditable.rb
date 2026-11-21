module Admin
  # Records every mutating admin action with the admin, the auditable record,
  # a JSON-safe changeset and the request IP.
  module Auditable
    extend ActiveSupport::Concern

    SENSITIVE_ATTRIBUTES = %w[
      encrypted_password reset_password_token confirmation_token unlock_token
      remember_created_at current_sign_in_ip last_sign_in_ip
    ].freeze

    private

    def audit!(action, auditable, changeset: nil)
      AdminAuditLog.create!(
        admin: auditing_admin,
        action: action.to_s,
        auditable: auditable,
        changeset: sanitise_changeset(changeset || default_changeset(auditable)),
        ip: request.remote_ip
      )
    end

    def auditing_admin
      if respond_to?(:current_impersonator, true)
        current_impersonator || current_user
      else
        current_user
      end
    end

    def default_changeset(auditable)
      return {} unless auditable.respond_to?(:saved_changes)

      auditable.saved_changes
    end

    def sanitise_changeset(changeset)
      changeset.to_h
                .deep_stringify_keys
                .except(*SENSITIVE_ATTRIBUTES)
                .transform_values { |value| json_safe(value) }
    end

    def json_safe(value)
      case value
      when Array then value.map { |entry| json_safe(entry) }
      when Hash then value.transform_values { |entry| json_safe(entry) }
      when Time, Date, DateTime then value.iso8601
      else value
      end
    end
  end
end
