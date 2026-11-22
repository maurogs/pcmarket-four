require "test_helper"

class DemoSeedTest < ActiveSupport::TestCase
  test "demo seed scales down, runs without network and is idempotent" do
    previous = ENV.to_h.slice("DEMO_SEED", "DEMO_SCALE", "DEMO_IMAGES")
    ENV["DEMO_SEED"] = "1"
    ENV["DEMO_SCALE"] = "0.05"
    ENV["DEMO_IMAGES"] = "0"

    Demo::Reset.call

    load Rails.root.join("db/seeds.rb")
    first_counts = demo_counts

    assert_operator first_counts[:listings], :>, 0
    assert_operator first_counts[:stores], :>, 0
    assert_operator first_counts[:buyers], :>, 0
    assert_operator first_counts[:orders], :>, 0
    assert_operator first_counts[:conversations], :>, 0
    assert_equal 0, ActiveStorage::Attachment.where(record_type: "Listing").count,
                 "demo images must stay off with DEMO_IMAGES=0"

    load Rails.root.join("db/seeds/demo.rb")

    assert_equal first_counts, demo_counts
  ensure
    %w[DEMO_SEED DEMO_SCALE DEMO_IMAGES].each do |key|
      if previous&.key?(key)
        ENV[key] = previous[key]
      else
        ENV.delete(key)
      end
    end
    Demo::Reset.call
  end

  private

  def demo_counts
    demo_users = User.where("email LIKE ?", "%@demo.pcmarket.test")
    demo_listings = Listing.where(user_id: demo_users.select(:id))
    demo_orders = Order.where(buyer_id: demo_users.select(:id))
                       .or(Order.where(seller_id: demo_users.select(:id)))

    {
      users: demo_users.count,
      buyers: demo_users.where("email LIKE ?", "buyer%").count,
      stores: Store.where(user_id: demo_users.select(:id)).count,
      listings: demo_listings.count,
      orders: demo_orders.count,
      conversations: Conversation.where(buyer_id: demo_users.select(:id))
                                 .or(Conversation.where(seller_id: demo_users.select(:id))).count,
      reviews: Review.where(order_id: demo_orders.select(:id)).count,
      favorites: Favorite.where(user_id: demo_users.select(:id)).count
    }
  end
end
