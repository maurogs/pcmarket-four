module Admin
  class DisputePolicy < BasePolicy
    def resolve?
      staff?
    end

    def refund?
      admin?
    end

    def release?
      staff?
    end
  end
end
