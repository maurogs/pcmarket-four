# A seller's public storefront. Created lazily by Stores::EnsureForUser —
# every user who lists something for sale gets exactly one.
class Store < ApplicationRecord
  extend FriendlyId

  # Business identity is only required for business accounts.
  enum :kind, { individual: 0, business: 1 }, default: :individual

  belongs_to :user
  belongs_to :country, optional: true
  has_many :listings, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :followers, through: :follows, source: :follower
  has_many :reviews, dependent: :destroy

  has_one_attached :logo
  has_one_attached :banner

  friendly_id :slug_source, use: :slugged

  validates :name, presence: true, length: { maximum: 60 }
  validates :slug, presence: true, uniqueness: true, allow_nil: true
  validates :bio, length: { maximum: 2000 }
  validates :business_name, :tax_id, presence: true, if: :business?
  validates :rating_avg, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validates :ratings_count, :sales_count, :followers_count, :active_listings_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :verified, -> { where(verified: true) }
  scope :not_on_vacation, -> { where(vacation_mode: false) }

  # Slug lookups for seller URLs (/stores/:slug).
  def self.find_by_param(param)
    find_by(slug: param.to_s)
  end

  def display_name
    business? ? business_name.presence || name : name
  end

  def verified!
    update!(verified: true, verified_at: Time.current)
  end

  def slug_source
    name
  end
end
