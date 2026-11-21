class Review < ApplicationRecord
  BODY_MIN = 20
  BODY_MAX = 1000

  belongs_to :order, inverse_of: :review
  belongs_to :reviewer, class_name: "User", inverse_of: :reviews
  belongs_to :store, inverse_of: false

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :order_id, uniqueness: true
  validates :body, presence: true, length: { minimum: BODY_MIN, maximum: BODY_MAX }
  validates :seller_reply, length: { maximum: BODY_MAX }, allow_blank: true
  validate :order_must_be_completed
  validate :body_must_be_clean
  validate :reply_must_be_clean

  after_commit :refresh_store_rating, on: %i[create update destroy]

  def replied?
    seller_reply.present?
  end

  def reply!(text)
    update!(seller_reply: text.to_s.strip)
  end

  private

  def order_must_be_completed
    return if order.blank? || order.completed? || order.delivered?

    errors.add(:order, I18n.t("orders.reviews.order_not_completed"))
  end

  def body_must_be_clean
    errors.add(:body, I18n.t("orders.reviews.blocked")) if ProfanityFilter.blocked?(body)
  end

  def reply_must_be_clean
    errors.add(:seller_reply, I18n.t("orders.reviews.blocked")) if ProfanityFilter.blocked?(seller_reply)
  end

  def refresh_store_rating
    Store.find_by(id: store_id)&.recalculate_rating!
  end
end
