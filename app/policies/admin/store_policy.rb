module Admin
  class StorePolicy < BasePolicy
    def verify?
      staff?
    end

    def unverify?
      staff?
    end

    def vacation?
      staff?
    end

    def end_vacation?
      staff?
    end
  end
end
