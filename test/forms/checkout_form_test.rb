require "test_helper"

class CheckoutFormTest < ActiveSupport::TestCase
  setup do
    @user = users(:confirmed)
  end

  # --- contact / terms ----------------------------------------------------------

  test "a complete inline address form is valid" do
    assert_predicate build_form, :valid?
  end

  test "guests must provide an email" do
    form = build_form(email: nil)
    assert_not_predicate form, :valid?
    assert_includes form.errors.attribute_names, :email
  end

  test "signed-in users may leave the email empty" do
    assert_predicate build_form(user: @user, email: nil), :valid?
  end

  test "the email format is validated" do
    assert_not_predicate build_form(email: "nope"), :valid?
  end

  test "the terms must be accepted" do
    assert_not_predicate build_form(accept_terms: "0"), :valid?
  end

  # --- shipping address -----------------------------------------------------------

  test "inline address errors are copied from the Address model" do
    form = build_form(postal_code: "", city: nil)

    assert_not_predicate form, :valid?
    assert_includes form.errors.attribute_names, :postal_code
    assert_includes form.errors.attribute_names, :city
  end

  test "the postal code must match the province" do
    form = build_form(province: "08", postal_code: "28001")

    assert_not_predicate form, :valid?
    assert_includes form.errors[:province],
      I18n.t("activerecord.errors.models.address.attributes.province.postal_code_mismatch")
  end

  test "a saved address of the user is used as-is" do
    address = create_address(user: @user)
    form = build_form(user: @user, address_id: address.id, first_name: nil, postal_code: nil)

    assert_predicate form, :valid?
    assert_equal address, form.shipping_address
  end

  test "an address the user does not own is rejected" do
    form = build_form(user: @user, address_id: create_address(user: users(:pending)).id)

    assert_not_predicate form, :valid?
    assert_includes form.errors.attribute_names, :address_id
  end

  test "guests cannot pick a saved address" do
    form = build_form(address_id: create_address(user: @user).id)

    assert_not_predicate form, :valid?
    assert_includes form.errors.attribute_names, :address_id
  end

  # --- payment method / save_address ------------------------------------------------

  test "the payment method is pinned to manual while payments are disabled" do
    form = build_form(payments_enabled: false, payment_method: "stripe")

    assert_equal "manual", form.payment_method
  end

  test "the payment method defaults to stripe when payments are enabled" do
    form = build_form(payments_enabled: true, payment_method: nil)

    assert_equal "stripe", form.payment_method
    assert_equal "stripe", form.placer_payment_method
  end

  test "stripe is passed through to the Placer when payments are enabled" do
    form = build_form(payments_enabled: true, payment_method: "stripe")

    assert_predicate form, :valid?
    assert_equal "stripe", form.placer_payment_method
  end

  test "manual stays available while the manual_payments_enabled setting is on" do
    form = build_form(payments_enabled: true, manual_payments_enabled: true, payment_method: "manual")

    assert_predicate form, :valid?
    assert_equal "manual", form.placer_payment_method
  end

  test "manual is rejected when the manual_payments_enabled setting is off" do
    form = build_form(payments_enabled: true, manual_payments_enabled: false, payment_method: "manual")

    assert_not_predicate form, :valid?
    assert_includes form.errors.attribute_names, :payment_method
  end

  test "address_to_save is the inline address only for signed-in opt-ins" do
    assert_nil build_form.address_to_save
    assert_nil build_form(user: @user).address_to_save
    assert_nil build_form(user: @user, save_address: "1",
                          address_id: create_address(user: @user).id).address_to_save

    address = build_form(user: @user, save_address: "1").address_to_save
    assert_not_predicate address, :persisted?
    assert_equal @user, address.user
  end

  private

  def create_address(user:)
    Address.create!(user: user, country: countries(:es), first_name: "Mauro", last_name: "Lopez",
                    street_line1: "Calle Mayor 1", postal_code: "28001", city: "Madrid",
                    province: "28")
  end

  def build_form(user: nil, payments_enabled: false, manual_payments_enabled: true, **overrides)
    defaults = {
      email: "buyer@example.com",
      first_name: "Mauro", last_name: "Lopez",
      street_line1: "Calle Mayor 1", city: "Madrid",
      province: "28", postal_code: "28001", phone: "600123456",
      accept_terms: "1", payment_method: "manual"
    }
    CheckoutForm.new(user: user, payments_enabled: payments_enabled,
                     manual_payments_enabled: manual_payments_enabled,
                     **defaults.merge(overrides))
  end
end
