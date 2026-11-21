module Admin
  # Catalogue and content mutations are administrator-only in phase 6C.
  # Moderators keep read access through the inherited staff predicates.
  class CataloguePolicy < BasePolicy
    def create?
      admin?
    end

    def new?
      create?
    end

    def update?
      admin?
    end

    def edit?
      update?
    end

    def destroy?
      admin?
    end
  end
end
