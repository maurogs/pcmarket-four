# A user's review of a store (optionally tied to a listing/order). Published
# reviews feed Store#rating_avg / #ratings_count through
# Stores::RatingRecalculator; authors can't review their own store.
class Review < ApplicationRecord
  enum :status, { published: "published", hidden: "hidden" }, default: :published

  belongs_to :store
  belongs_to :author, class_name: "User"
  belongs_to :listing, optional: true

  validates :rating, numericality: { only_integer: true, in: 1..5 }
  validates :title, length: { maximum: 120 }, allow_nil: true
  validates :body, length: { maximum: 2000 }, allow_nil: true
  validate :not_own_store

  scope :recent, -> { order(created_at: :desc) }

  after_commit :recalculate_store_rating, on: %i[create update destroy]

  private

  def not_own_store
    errors.add(:store, :reviewing_own_store) if store && author_id == store.user_id
  end

  def recalculate_store_rating
    Stores::RatingRecalculator.call(store)
  end
end
