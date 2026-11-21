class AdminAuditLog < ApplicationRecord
  belongs_to :admin, class_name: "User", inverse_of: false
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
