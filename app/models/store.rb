class Store < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  belongs_to :user, inverse_of: :store
  belongs_to :region, optional: true, inverse_of: :stores

  has_many :listings, dependent: :nullify, inverse_of: :store
  has_many :follows, dependent: :destroy, inverse_of: :store
  has_many :followers, through: :follows, source: :follower
  has_many :orders, dependent: :nullify, inverse_of: :store

  has_one_attached :logo
  has_one_attached :banner

  enum :store_type, { individual: 0, professional: 1 }

  validates :name, presence: true, length: { maximum: 80 }
  validates :user_id, uniqueness: true

  scope :verified, -> { where(verified: true) }
  scope :available, -> { where(vacation_mode: false) }

  def recalculate_rating!
    published_reviews = Review.where(store_id: id, published: true)
    update_columns(
      rating_avg: published_reviews.average(:rating)&.round(2) || 0,
      reviews_count: published_reviews.count,
      updated_at: Time.current
    )
  end

  def to_s
    name
  end
end
