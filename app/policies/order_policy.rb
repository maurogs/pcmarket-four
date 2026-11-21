class OrderPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    buyer? || staff?
  end

  def cancellation?
    buyer? && record.cancellable?
  end

  def delivery_confirmation?
    buyer? && record.shipped?
  end

  def dispute?
    buyer? && record.inspection_window_open? &&
      %w[shipped delivered].include?(record.status)
  end

  def review?
    buyer? && record.completed? && record.review.blank?
  end

  private

  def buyer?
    user.present? && record.buyer_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.where(buyer_id: user.id) : scope.none
    end
  end
end
