require "test_helper"

class FollowTest < ActiveSupport::TestCase
  setup do
    @store = stores(:confirmed_store)
    @follower = create_user("fan")
  end

  test "following bumps the store's followers counter cache" do
    follow = Follow.create!(follower: @follower, store: @store)

    assert_equal 1, @store.reload.followers_count

    follow.destroy

    assert_equal 0, @store.reload.followers_count
  end

  test "users can't follow their own store" do
    follow = Follow.new(follower: users(:confirmed), store: @store)

    assert_not follow.valid?
    assert follow.errors.of_kind?(:store, :following_own_store)
  end

  test "duplicate follows are rejected" do
    Follow.create!(follower: @follower, store: @store)

    assert_raises(ActiveRecord::RecordInvalid) do
      Follow.create!(follower: @follower, store: @store)
    end
    assert_equal 1, Follow.where(follower: @follower, store: @store).count
  end

  test "following? reflects the follows" do
    assert_not @follower.following?(@store)

    Follow.create!(follower: @follower, store: @store)

    assert @follower.reload.following?(@store)
    assert_not users(:pending).following?(@store)
  end

  test "destroying a user or store removes the follows" do
    Follow.create!(follower: @follower, store: @store)

    @follower.destroy!

    assert_equal 0, @store.reload.followers_count
    assert_equal 0, Follow.count
  end

  private

  def create_user(name)
    User.create!(email: "#{name}@example.com", username: name,
                 password: "password123", confirmed_at: Time.current)
  end
end
