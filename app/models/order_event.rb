class OrderEvent < ApplicationRecord
  KINDS = %w[
    placed paid shipped ready_for_pickup delivered completed cancelled
    dispute_opened dispute_resolved refunded late_shipment_reminder
  ].freeze

  belongs_to :order, inverse_of: :order_events
  belongs_to :actor, class_name: "User", optional: true

  validates :kind, presence: true, inclusion: { in: KINDS }

  scope :chronological, -> { order(:created_at, :id) }

  def system?
    actor_id.nil?
  end
end
