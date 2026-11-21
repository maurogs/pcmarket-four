module Admin
  class ReportPolicy < BasePolicy
    def resolve?
      staff?
    end

    def dismiss?
      staff?
    end

    def bulk?
      staff?
    end

    def delete_review?
      admin?
    end

    def suspend_user?
      staff?
    end
  end
end
