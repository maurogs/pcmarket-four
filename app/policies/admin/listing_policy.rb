module Admin
  class ListingPolicy < BasePolicy
    def approve?
      staff?
    end

    def reject?
      staff?
    end

    def bulk?
      staff?
    end

    def feature?
      staff?
    end
  end
end
