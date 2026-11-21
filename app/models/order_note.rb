class OrderNote < ApplicationRecord
  belongs_to :order, inverse_of: :order_notes
  belongs_to :author, class_name: "User", inverse_of: false

  validates :body, presence: true, length: { maximum: 2_000 }

  scope :chronological, -> { order(:created_at, :id) }
end
