module Admin
  class FeatureRequestPolicy < Admin::CataloguePolicy
    def approve?
      admin?
    end
  end
end
