module Admin
  class UserPolicy < BasePolicy
    def suspend?
      staff?
    end

    def unsuspend?
      staff?
    end

    def ban?
      admin?
    end

    def unban?
      admin?
    end

    def role?
      admin?
    end

    def confirm_email?
      staff?
    end

    def send_password_reset?
      staff?
    end

    def impersonate?
      admin? && record.is_a?(User) && !record.admin? && record != user
    end

    def export?
      staff?
    end
  end
end
