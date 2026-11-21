class Order < ApplicationRecord
  NUMBER_PREFIX = "PCM"

  belongs_to :buyer, class_name: "User", inverse_of: :orders_as_buyer
  belongs_to :seller, class_name: "User", inverse_of: :orders_as_seller
  belongs_to :store, optional: true, inverse_of: :orders

  has_many :order_items, dependent: :destroy, inverse_of: :order
  has_many :listings, through: :order_items
  has_one :review, dependent: :destroy, inverse_of: :order

  enum :status, {
    pending_payment: 0,
    paid: 1,
    shipped: 2,
    delivered: 3,
    completed: 4,
    cancelled: 5,
    refunded: 6,
    disputed: 7
  }
  enum :fulfilment, { shipping: 0, local_pickup: 1 }

  before_validation :assign_number, on: :create

  validates :number, presence: true, uniqueness: true
  validates :subtotal_cents, :shipping_cents, :commission_cents, :total_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def compute_totals!
    self.subtotal_cents = order_items.sum { |item| item.price_cents.to_i * item.quantity.to_i }

    if Setting.enabled?("commissions_enabled")
      self.commission_percent = BigDecimal(Setting.get("commission_percent", 0).to_s)
      self.commission_cents = (subtotal_cents * commission_percent / 100).round
    else
      self.commission_percent = 0
      self.commission_cents = 0
    end

    self.total_cents = subtotal_cents + shipping_cents.to_i
    save!
    self
  end

  def net_to_seller_cents
    subtotal_cents - commission_cents
  end

  def to_param
    number
  end

  private

  def assign_number
    return if number.present?

    year = Time.current.year
    sequence = self.class.where("number LIKE ?", "#{NUMBER_PREFIX}-#{year}-%").count + 1
    self.number = format("%s-%d-%06d", NUMBER_PREFIX, year, sequence)
  end
end
