require "test_helper"

class Accounts::DeleterTest < ActiveSupport::TestCase
  setup do
    @user = users(:confirmed)
    @listing = publish(create_listing(store: stores(:confirmed_store),
                                      title: "ASUS ProArt RTX 4080 SUPER 16GB"))
    @other_store = Store.create!(user: users(:pending), name: "Pending Store", slug: "pending-store")
    @review = create_review(store: @other_store, author: @user)
    @user.addresses.create!(country: countries(:es), first_name: "Ana", last_name: "López",
                            street_line1: "Calle Mayor 1", city: "Madrid",
                            province: "28", postal_code: "28001")
    @user.update!(notification_preferences: { "newsletter" => true }, marketing_opt_in: true)
    @user.avatar.attach(io: File.open(image_file("1x1.png")), filename: "avatar.png",
                        content_type: "image/png")
    @user.data_export.attach(io: StringIO.new("{}"), filename: "export.json",
                             content_type: "application/json")
  end

  test "anonymizes the user and stamps deleted_at" do
    Accounts::Deleter.call(@user)

    @user.reload
    assert_equal "deleted-#{@user.id}@deleted.invalid", @user.email
    assert_equal "deleted_user_#{@user.id}", @user.username
    assert_nil @user.first_name
    assert_nil @user.last_name
    assert_nil @user.phone
    assert_nil @user.unconfirmed_email
    assert_empty @user.notification_preferences
    assert_not @user.marketing_opt_in
    assert_nil @user.marketing_opt_in_at
    assert_not_predicate @user.avatar, :attached?
    assert_not_predicate @user.data_export, :attached?
    assert_predicate @user, :deleted?
  end

  test "email swap does not trigger Devise reconfirmation" do
    Accounts::Deleter.call(@user)

    @user.reload
    assert_not_predicate @user, :pending_reconfirmation?
    assert_nil @user.unconfirmed_email
    assert_not_nil @user.confirmed_at
  end

  test "archives every listing and puts the store on vacation" do
    draft = create_listing(store: stores(:confirmed_store), title: "Kingston Fury Beast 32GB DDR5")

    Accounts::Deleter.call(@user)

    assert_predicate @listing.reload, :archived?
    assert_predicate draft.reload, :archived?
    assert_predicate stores(:confirmed_store).reload, :vacation_mode?
  end

  test "keeps reviews written by the user" do
    Accounts::Deleter.call(@user)

    assert_not_nil Review.find_by(id: @review.id)
    assert_equal @user.id, @review.reload.author_id
  end

  test "erases shipping addresses" do
    Accounts::Deleter.call(@user)

    assert_empty @user.addresses.reload
  end

  test "a deleted user can never authenticate again" do
    Accounts::Deleter.call(@user)

    assert_not @user.reload.active_for_authentication?
  end
end
