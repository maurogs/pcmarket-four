module Admin
  class BasePolicy < ApplicationPolicy
    def index?
      staff?
    end

    def show?
      staff?
    end

    def create?
      staff?
    end

    def new?
      create?
    end

    def update?
      staff?
    end

    def edit?
      update?
    end

    def destroy?
      admin?
    end

    def dashboard?
      staff?
    end

    def search?
      staff?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        staff? ? scope.all : scope.none
      end
    end
  end
end
