require "test_helper"

module Api
  module V1
    class CatalogueTest < ActionDispatch::IntegrationTest
      include ApiTestHelper

      setup do
        @buyer = users(:buyer)
        @seller = users(:seller)
        @seller_token = issue_token_for(@seller)
        @listing = listings(:published_gpu)
      end

      test "returns the category tree with localized names and counts" do
        api_get "/api/v1/categories?locale=en", token: nil

        assert_response :ok
        root = json_body["data"].find { |category| category["slug"] == "components" }
        assert_equal "Components", root["name"]
        child = root["children"].find { |category| category["slug"] == "graphics-cards" }
        assert_equal "Graphics cards", child["name"]
        assert_kind_of Integer, child["listings_count"]
      end

      test "returns category filters and options" do
        api_get "/api/v1/categories/graphics-cards?locale=en", token: nil

        assert_response :ok
        data = json_body["data"]
        assert_equal "graphics-cards", data["slug"]
        assert data["filters"].any?
        filter = data["filters"].first
        assert filter.key?("key")
        assert filter.key?("options")
      end

      test "searches listings with filters, facets and active filters" do
        get "/api/v1/listings",
            params: { q: "RTX", condition: [ "used_like_new" ], sort: "price_asc", per_page: 10 },
            headers: api_headers(nil)

        assert_response :ok
        assert json_body["data"].any?
        meta = json_body["meta"]
        assert_equal 1, meta["page"]
        assert_equal 10, meta["per_page"]
        assert meta["total"].positive?
        assert meta["active_filters"].any?
        assert meta.key?("facets")
      end

      test "returns the seller listing board" do
        api_get "/api/v1/me/listings?status=published", token: @seller_token

        assert_response :ok
        assert json_body["data"].any?
        assert_equal "published", json_body["data"].first["status"]
      end

      test "shows a listing with absolute image and store data" do
        api_get "/api/v1/listings/#{@listing.slug}", token: nil

        assert_response :ok
        data = json_body["data"]
        assert_equal @listing.title, data["title"]
        assert_equal @listing.price_cents, data.dig("price", "cents")
        assert_equal "Falcon Tech", data.dig("store", "name")
        assert data.key?("images")
      end

      test "creates and updates a listing through ListingForm" do
        post "/api/v1/listings",
             params: { listing: {
               category_id: categories(:graphics_cards).id,
               title: "NVIDIA RTX 5080 Founders Edition",
               description: "Tarjeta gráfica nueva con caja original y garantía de dos años.",
               price: "1.299,00",
               condition: "new_open_box",
               quantity: 1,
               shipping_available: true,
               shipping_price: "9,90",
               local_pickup: true,
               tags: [ "rgb" ],
               specs: { vram_gb: "16" }
             } },
             headers: api_headers(@seller_token), as: :json

        assert_response :created
        slug = json_body.dig("data", "slug")
        assert slug.present?
        assert_equal 129_900, json_body.dig("data", "price", "cents")

        patch "/api/v1/listings/#{slug}",
              params: { listing: { price: "1.199,00" } },
              headers: api_headers(@seller_token), as: :json

        assert_response :ok
        assert_equal 119_900, json_body.dig("data", "price", "cents")
      end

      test "forbids editing another seller listing" do
        patch "/api/v1/listings/#{@listing.slug}",
              params: { listing: { title: "Hijacked listing title" } },
              headers: api_headers, as: :json

        assert_error_envelope 403, "forbidden"
        assert_equal "NVIDIA GeForce RTX 4070 Super 12 GB", @listing.reload.title
      end

      test "uploads images and submits a draft for review" do
        listing = listings(:draft_gpu)

        post "/api/v1/listings/#{listing.slug}/images",
             params: { images: [ fixture_file_upload("gpu.jpg", "image/jpeg") ] },
             headers: api_headers(@seller_token)

        assert_response :created
        assert json_body["data"].any?
        assert listing.reload.images.attached?

        post "/api/v1/listings/#{listing.slug}/submission", headers: api_headers(@seller_token),
                                                           as: :json

        assert_response :accepted
        assert_equal "pending_review", listing.reload.status
      end

      test "pauses, resumes and marks a listing sold" do
        post "/api/v1/listings/#{@listing.slug}/pause", headers: api_headers(@seller_token), as: :json
        assert_response :ok
        assert_equal "paused", @listing.reload.status

        delete "/api/v1/listings/#{@listing.slug}/pause", headers: api_headers(@seller_token)
        assert_response :ok
        assert_equal "published", @listing.reload.status

        post "/api/v1/listings/#{@listing.slug}/sale", headers: api_headers(@seller_token), as: :json
        assert_response :ok
        assert_equal "sold", @listing.reload.status
      end

      test "adds and removes a favourite" do
        post "/api/v1/listings/#{@listing.slug}/favorite", headers: api_headers, as: :json
        assert_response :created
        assert Favorite.where(user: @buyer, listing: @listing).exists?

        delete "/api/v1/listings/#{@listing.slug}/favorite", headers: api_headers
        assert_response :no_content
        assert_not Favorite.where(user: @buyer, listing: @listing).exists?
      end

      test "returns store detail, listings, reviews and follows" do
        api_get "/api/v1/stores/falcon-tech", token: nil
        assert_response :ok
        assert_equal "Falcon Tech", json_body.dig("data", "name")

        api_get "/api/v1/stores/falcon-tech/listings", token: nil
        assert_response :ok
        assert json_body["data"].any?

        api_get "/api/v1/stores/falcon-tech/reviews", token: nil
        assert_response :ok

        delete "/api/v1/stores/falcon-tech/follow", headers: api_headers
        assert_response :ok
        assert_not Follow.where(follower: @buyer, store: stores(:seller_store)).exists?

        post "/api/v1/stores/falcon-tech/follow", headers: api_headers, as: :json
        assert_response :created
        assert json_body.dig("data", "following")
      end

      test "manages saved searches" do
        post "/api/v1/me/saved_searches",
             params: { saved_search: { name: "RTX Barcelona", q: "RTX", max_price: 600 } },
             headers: api_headers, as: :json

        assert_response :created
        id = json_body.dig("data", "id")
        assert_equal "RTX Barcelona", json_body.dig("data", "name")

        patch "/api/v1/me/saved_searches/#{id}",
              params: { saved_search: { notify: false } },
              headers: api_headers, as: :json
        assert_response :ok
        assert_equal false, json_body.dig("data", "notify")

        api_get "/api/v1/me/saved_searches"
        assert_response :ok

        delete "/api/v1/me/saved_searches/#{id}", headers: api_headers
        assert_response :no_content
      end

      test "returns PC Finder recommendations" do
        get "/api/v1/pc_finder/results",
            params: { games: [ "fortnite" ], resolution: "1080p", fps: 144 },
            headers: api_headers(nil)

        assert_response :ok
        assert json_body["data"].is_a?(Array)
        assert json_body["meta"].key?("total")
      end

      test "serves help articles and legal pages" do
        api_get "/api/v1/help_articles", token: nil
        assert_response :ok
        assert json_body["data"].is_a?(Array)

        api_get "/api/v1/legal_pages/terms?country=ES", token: nil
        assert_response :ok
        assert_equal "terms", json_body.dig("data", "slug")
        assert json_body.dig("data", "body_html").present?
      end
    end
  end
end
