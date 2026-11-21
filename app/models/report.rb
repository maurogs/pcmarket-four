class Report < ApplicationRecord
  belongs_to :reporter, class_name: "User", inverse_of: :reports
  belongs_to :reportable, polymorphic: true
  belongs_to :resolved_by, class_name: "User", optional: true, inverse_of: false

  enum :reason, { spam: 0, fraud: 1, prohibited: 2, counterfeit: 3, offensive: 4, other: 5 }
  enum :status, { open: 0, resolved: 1, dismissed: 2 }

  validates :reason, presence: true
  validates :reportable_id, uniqueness: {
    scope: [ :reporter_id, :reportable_type ],
    conditions: -> { where(status: :open) },
    message: :already_reported
  }, if: -> { reporter_id.present? && reportable_id.present? }

  scope :pending, -> { where(status: :open) }

  def resolve!(admin)
    update!(status: :resolved, resolved_by_id: admin.id)
  end

  def dismiss!(admin)
    update!(status: :dismissed, resolved_by_id: admin.id)
  end
end
