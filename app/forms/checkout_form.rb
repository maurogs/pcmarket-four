# Form object behind the checkout page (Phase 4 step 3): contact email,
# shipping address (either one of the signed-in user's saved addresses or a
# fresh inline one), the terms acceptance and the payment method.
#
# The inline address is validated by building an unsaved Address with the
# Spanish market country and copying its errors onto the form, so the
# postcode/province consistency rules live in one place (see Address).
# While payments are active (AppSettings flag AND Stripe credentials, see
# Payments.active?) the method defaults to "stripe"; "manual" stays offered
# only while the manual_payments_enabled setting is on. With payments off the
# method is pinned to "manual". Whether Stripe can actually be used for the
# cart (every store payment-ready) is decided by the controller.
class CheckoutForm
  include ActiveModel::Model

  attr_reader :user

  attr_accessor :email, :address_id, :first_name, :last_name, :street_line1,
                :street_line2, :city, :province, :postal_code, :phone,
                :save_address, :buyer_note, :accept_terms, :payment_method

  validates :email, presence: true, if: -> { user.nil? }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }
  validates :payment_method, inclusion: { in: Order::PAYMENT_METHODS }
  validates :accept_terms, acceptance: true
  validate :manual_payment_allowed
  validate :shipping_address_valid

  def initialize(user: nil, payments_enabled: Payments.active?,
                 manual_payments_enabled: AppSettings.enabled?(:manual_payments_enabled),
                 **attributes)
    @user = user
    @payments_enabled = payments_enabled
    @manual_payments_enabled = manual_payments_enabled
    super(attributes)
    self.payment_method = "manual" unless @payments_enabled
    self.payment_method = "stripe" if @payments_enabled && payment_method.blank?
  end

  def payments_enabled?
    @payments_enabled
  end

  def manual_payments_enabled?
    @manual_payments_enabled
  end

  # The method the Placer receives; the controller may still downgrade
  # "stripe" to "manual" when a cart store is not payment-ready.
  def placer_payment_method
    payment_method
  end

  # Address handed to the Placer: the chosen saved address, or the unsaved
  # inline one (never persisted unless the caller saves #address_to_save).
  def shipping_address
    chosen_address || built_address
  end

  def save_address?
    ActiveModel::Type::Boolean.new.cast(save_address)
  end

  # The unsaved inline address to persist into the buyer's address book:
  # only for signed-in users who ticked the box and typed a new address.
  def address_to_save
    return nil unless save_address? && user.present? && address_id.blank?

    built_address
  end

  private

  # With payments active the manual option is an admin choice: rejecting a
  # hand-crafted "manual" submission keeps the setting authoritative.
  def manual_payment_allowed
    return unless payments_enabled? && payment_method == "manual" && !manual_payments_enabled?

    errors.add(:payment_method, :unavailable)
  end

  def shipping_address_valid
    if address_id.present?
      errors.add(:address_id, :not_found) if chosen_address.nil?
      return
    end

    address = built_address
    return if address.valid?

    address.errors.each do |error|
      next if %i[user country].include?(error.attribute)

      errors.add(error.attribute, error.type, message: error.message)
    end
  end

  def chosen_address
    return if address_id.blank? || user.nil?

    @chosen_address ||= user.addresses.find_by(id: address_id)
  end

  # Guests get an unsaved User so the Address belongs_to presence passes;
  # the record is never persisted for them (#address_to_save stays nil).
  def built_address
    @built_address ||= Address.new(
      user: user || User.new, country: spain,
      first_name: first_name, last_name: last_name,
      street_line1: street_line1, street_line2: street_line2,
      city: city, province: province, postal_code: postal_code, phone: phone
    )
  end

  # Checkout ships to the Spanish market only for now (see the province
  # select); fall back to an unsaved row when the market row is missing.
  def spain
    @spain ||= Country.find_by(code: Address::SPAIN_CODE) ||
               Country.new(code: Address::SPAIN_CODE, enabled: true)
  end
end
