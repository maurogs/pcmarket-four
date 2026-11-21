module Admin
  class OrderPolicy < BasePolicy
    def mark_paid?
      staff?
    end

    def cancel?
      staff?
    end

    def refund?
      admin?
    end

    def release?
      staff?
    end

    def note?
      staff?
    end

    def resend_email?
      staff?
    end

    def export?
      staff?
    end

    def bulk_payment?
      staff?
    end
  end
end
