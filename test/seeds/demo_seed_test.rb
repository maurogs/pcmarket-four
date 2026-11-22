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
    assert_demo_content_quality
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

  def assert_demo_content_quality
    demo_users = User.where("email LIKE ?", "%@demo.pcmarket.test").select(:id)
    listings = Listing.where(user_id: demo_users).to_a

    assert listings.none? { |listing| listing.title.include?("·") },
           "listing titles must not append the condition"
    assert listings.all? { |listing| allowed_price?(listing.price_cents) },
           "listing prices must end in 0, 5, 9 or .99 euros"
    assert(
      listings.all? { |listing| listing.original_price_cents.nil? || allowed_price?(listing.original_price_cents) },
      "original prices must use the same rounding"
    )
    assert listings.none? { |listing| listing.description.include?("Cpu brand") },
           "descriptions must use translated filter names"

    translated = listings.find { |listing| listing.description.include?("Marca del procesador") }
    assert_not_nil translated, "Spanish descriptions should use FilterDefinition names"
    fps_listing = listings.find { |listing| listing.description.include?("alcanza aproximadamente") }
    assert_not_nil fps_listing, "gaming PC descriptions should include complete FPS sentences"
    fps_listing.description.lines.grep(/alcanza aproximadamente/).each do |line|
      assert line.strip.end_with?("."), "FPS sentences must end with a full stop"
    end
  end

  def allowed_price?(cents)
    [ 0, 5, 9 ].include?(cents % 100) || cents % 100 == 99
  end

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
