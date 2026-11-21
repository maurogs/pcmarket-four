module Admin
  class ReviewPolicy < BasePolicy
    def publish?
      staff?
    end

    def unpublish?
      staff?
    end

    def visibility?
      staff?
    end
  end
end
