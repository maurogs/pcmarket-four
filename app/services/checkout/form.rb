module Checkout
  # Form object for the single-page checkout. It owns validation for contact,
  # delivery (per seller group), payment method and the EU legal checkboxes so
  # the controller stays thin and PlaceOrder receives trusted input.
  class Form
    include ActiveModel::Model

    ADDRESS_FIELDS = %i[full_name line1 line2 city postal_code region_id country_code phone].freeze

    attr_accessor :summary, :user, :email, :delivery, :address_id, :save_address,
                  :payment_method, :terms_accepted, :withdrawal_acknowledged,
                  :checkout_token, :full_name, :line1, :line2, :city, :postal_code,
                  :region_id, :country_code, :phone

    def initialize(summary:, user: nil, **attributes)
      @summary = summary
      @user = user
      @delivery = {}
      @country_code = default_country_code
      @payment_method = default_payment_method
      @checkout_token = SecureRandom.uuid
      super(**attributes)
    end

    def guest?
      user.blank?
    end

    def groups
      summary.groups
    end

    def delivery_for(group)
      return "local_pickup" if group.pickup_only?

      value = delivery.to_h[group.seller.id.to_s].presence || delivery.to_h[group.seller.id]
      %w[shipping local_pickup].include?(value) ? value : "shipping"
    end

    def shipping_groups
      groups.select { |group| delivery_for(group) == "shipping" }
    end

    def pickup_only?
      groups.any? && groups.all? { |group| delivery_for(group) == "local_pickup" }
    end

    def saved_address
      return nil if user.blank? || address_id.blank?

      @saved_address ||= user.addresses.find_by(id: address_id)
    end

    def shipping_address
      return @shipping_address if defined?(@shipping_address)

      @shipping_address = if saved_address.present?
        {
          full_name: saved_address.full_name,
          line1: saved_address.line1,
          line2: saved_address.line2,
          city: saved_address.city,
          postal_code: saved_address.postal_code,
          region_id: saved_address.region_id,
          region_name: saved_address.region&.name,
          country_code: saved_address.country_code,
          phone: saved_address.phone
        }
      else
        {
          full_name: full_name,
          line1: line1,
          line2: line2,
          city: city,
          postal_code: postal_code,
          region_id: region_id.presence,
          region_name: Region.find_by(id: region_id)&.name,
          country_code: country_code,
          phone: phone
        }
      end
    end

    def save_address?
      ActiveModel::Type::Boolean.new.cast(save_address) == true && user.present? && saved_address.blank?
    end

    def available_payment_methods
      @available_payment_methods ||= Payments::Availability.new(summary).options
    end

    validate :run_checks

    private

    def run_checks
      validate_contact
      validate_delivery
      validate_address if shipping_groups.any?
      validate_payment
      validate_legal
    end

    def validate_contact
      if email.blank?
        errors.add(:email, I18n.t("checkout.errors.email_blank"))
      elsif !email.to_s.match?(URI::MailTo::EMAIL_REGEXP)
        errors.add(:email, I18n.t("checkout.errors.email_invalid"))
      end
    end

    def validate_delivery
      errors.add(:base, I18n.t("checkout.errors.empty_cart")) if groups.empty?
      return unless summary.available?

      errors.add(:base, I18n.t("checkout.errors.unavailable_items")) unless groups.all? do |group|
        group.available_items.any?
      end

      groups.each do |group|
        next if group.pickup_only?
        next unless delivery_for(group) == "shipping"
        next if group.available_items.all? { |item| item.listing.shipping_available? }

        errors.add(:base, I18n.t("checkout.errors.shipping_not_allowed"))
      end
    end

    def validate_address
      address = shipping_address

      ADDRESS_FIELDS.each do |field|
        next if field == :line2
        next if field == :phone
        next if field == :region_id && address[:country_code] != "ES"

        errors.add(:base, I18n.t("checkout.errors.address_incomplete")) if address[field].blank?
      end

      validate_country(address[:country_code])
      validate_postal_code(address)
    end

    def validate_country(code)
      return if code.blank?

      errors.add(:base, I18n.t("checkout.errors.country_not_enabled")) unless Country.enabled.exists?(code: code)
    end

    def validate_postal_code(address)
      return unless address[:country_code] == "ES"
      return if address[:postal_code].blank?

      unless address[:postal_code].to_s.match?(/\A\d{5}\z/)
        errors.add(:base, I18n.t("checkout.errors.postal_code_invalid"))
        return
      end

      region = Region.find_by(id: address[:region_id])
      return if region&.code.blank? || !region.code.match?(/\A\d{2}\z/)

      return if address[:postal_code].to_s.first(2) == region.code

      errors.add(:base, I18n.t("checkout.errors.postal_code_province"))
    end

    def validate_payment
      if payment_method.blank?
        errors.add(:base, I18n.t("checkout.errors.payment_required"))
      elsif available_payment_methods.exclude?(payment_method)
        errors.add(:base, I18n.t("checkout.errors.payment_unavailable"))
      end
    end

    def validate_legal
      unless ActiveModel::Type::Boolean.new.cast(terms_accepted) == true
        errors.add(:base, I18n.t("checkout.errors.terms_required"))
      end

      return if ActiveModel::Type::Boolean.new.cast(withdrawal_acknowledged) == true

      errors.add(:base, I18n.t("checkout.errors.withdrawal_required"))
    end

    def default_country_code
      Country.enabled.order(:code).first&.code || "ES"
    end

    def default_payment_method
      Payments::Availability.new(summary).options.first || "bank_transfer"
    end
  end
end
