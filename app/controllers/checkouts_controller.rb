class CheckoutsController < ApplicationController
  before_action :ensure_checkout_enabled
  before_action :load_summary

  def show
    if @summary.empty?
      redirect_to cart_path, alert: t("checkout.errors.empty_cart") and return
    end

    prepare_form
  end

  def create
    if @summary.empty?
      redirect_to cart_path, alert: t("checkout.errors.empty_cart") and return
    end

    @form = Checkout::Form.new(summary: @summary, user: current_user, **checkout_form_params)

    unless @form.valid?
      prepare_view
      return render :show, status: :unprocessable_content
    end

    orders = Checkout::PlaceOrder.new(form: @form, summary: @summary).call
    remember_checkout(orders)
    redirect_to payment_redirect(orders).presence || checkout_confirmation_path
  rescue Checkout::PlaceOrder::Error => error
    @form.errors.add(:base, t("checkout.errors.#{error.message_key}"))
    prepare_view
    render :show, status: :unprocessable_content
  end

  private

  def ensure_checkout_enabled
    return if Setting.enabled?("checkout_enabled")

    redirect_to cart_path, alert: t("checkout.disabled")
  end

  def load_summary
    @summary = cart_summary
  end

  def prepare_form
    session[:checkout_token] ||= SecureRandom.uuid
    default_address = current_user&.addresses&.default_address&.first

    @form = Checkout::Form.new(
      summary: @summary,
      user: current_user,
      email: current_user&.email,
      checkout_token: session[:checkout_token],
      full_name: default_address&.full_name,
      line1: default_address&.line1,
      line2: default_address&.line2,
      city: default_address&.city,
      postal_code: default_address&.postal_code,
      region_id: default_address&.region_id,
      country_code: default_address&.country_code.presence || Country.enabled.order(:code).first&.code
    )
    prepare_view
  end

  def prepare_view
    @addresses = current_user ? current_user.addresses.includes(:region).ordered.to_a : []
    @countries = Country.enabled.order(:code)
    @regions = Region.where(country_code: "ES").order(:name)
    @availability = Payments::Availability.new(@summary)
  end

  def remember_checkout(orders)
    session[:checkout_token] = @form.checkout_token
    session[:checkout_order_ids] = orders.map(&:id)
  end

  def payment_redirect(orders)
    return nil if orders.empty?

    provider = Payments.provider_for(orders.first.payment_method)
    provider.start(
      orders,
      success_url: checkout_confirmation_url,
      cancel_url: checkout_url
    )
  end

  def checkout_form_params
    params.require(:checkout).permit(
      :email, :payment_method, :address_id, :save_address, :terms_accepted,
      :withdrawal_acknowledged, :checkout_token, :full_name, :line1, :line2, :city,
      :postal_code, :region_id, :country_code, :phone,
      delivery: {}
    ).to_h.symbolize_keys
  end
end
