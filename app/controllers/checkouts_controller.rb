# GET  /checkout — the checkout form (Phase 4 step 3): contact email, the
# shipping address (saved or inline), the manual payment explanation and
# the order summary sidebar. POST /checkout validates the CheckoutForm and
# hands the cart to Orders::Placer: success redirects to the confirmation
# page of the placed checkout_group, a cart that changed under the buyer
# bounces back to the cart with the Placer errors, an invalid form re-renders
# with 422. Guests may check out only while guest_checkout_enabled is on.
class CheckoutsController < ApplicationController
  include CurrentCart

  before_action :require_checkout_enabled
  before_action :require_sign_in_for_guests
  before_action :set_cart

  def show
    @form = prefill_form
    @groups = @cart.items_by_store
  end

  def create
    @form = CheckoutForm.new(user: current_user, **checkout_params.to_h.symbolize_keys)
    @groups = @cart.items_by_store

    if @form.invalid?
      render :show, status: :unprocessable_entity
      return
    end

    place_orders
  end

  private

  def require_sign_in_for_guests
    authenticate_user! unless user_signed_in? || AppSettings.enabled?(:guest_checkout_enabled)
  end

  def set_cart
    @cart = current_cart
    return if @cart && @cart.cart_items.exists?

    redirect_to cart_path, alert: t("checkouts.flashes.empty_cart")
  end

  # Prefilled from the signed-in user's profile and default address.
  def prefill_form
    CheckoutForm.new(
      user: current_user,
      email: current_user&.email,
      address_id: current_user&.addresses&.defaults_first&.first&.id,
      first_name: current_user&.first_name,
      last_name: current_user&.last_name,
      phone: current_user&.phone
    )
  end

  def place_orders
    result = Orders::Placer.call(
      cart: @cart, buyer: current_user, email: @form.email,
      shipping_address: @form.shipping_address, shipping_method: "delivery",
      payment_method: @form.placer_payment_method, buyer_note: @form.buyer_note
    )

    if result.success?
      @form.address_to_save&.save!
      remember_checkout_group(result.checkout_group)
      redirect_to checkout_confirmation_path(result.checkout_group),
                  notice: t("checkouts.flashes.placed")
    else
      redirect_to cart_path, alert: result.errors.join(" ")
    end
  end

  # Guest orders carry no buyer_id, so the confirmation page finds them
  # through the groups placed in this session (cookie store, capped).
  def remember_checkout_group(group)
    session[:checkout_groups] = [ *session[:checkout_groups], group ].uniq.last(10)
  end

  def checkout_params
    params.expect(checkout_form: [ :email, :address_id, :first_name, :last_name,
      :street_line1, :street_line2, :city, :province, :postal_code, :phone,
      :save_address, :buyer_note, :accept_terms, :payment_method ])
  end
end
