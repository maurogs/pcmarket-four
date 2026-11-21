class Review < ApplicationRecord
  belongs_to :order, inverse_of: :review
  belongs_to :reviewer, class_name: "User", inverse_of: :reviews
  belongs_to :store, inverse_of: false

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :order_id, uniqueness: true

  after_commit :refresh_store_rating, on: %i[create update destroy]

  private

  def refresh_store_rating
    Store.find_by(id: store_id)&.recalculate_rating!
  end
end
