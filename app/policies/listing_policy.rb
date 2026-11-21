class ListingPolicy < ApplicationPolicy
  def show?
    record.visible? || owner? || staff?
  end

  def create?
    user.present? && user.active_account?
  end

  def update?
    owner? || admin?
  end

  def destroy?
    owner? || admin?
  end

  def approve?
    staff?
  end

  def reject?
    staff?
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.present? && user.staff?
        scope.all
      else
        scope.visible
      end
    end
  end
end
