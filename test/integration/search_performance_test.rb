require "test_helper"

class SearchPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    24.times do |index|
      Listing.create!(
        user: users(:seller),
        store: stores(:seller_store),
        category: categories(:graphics_cards),
        title: "Tarjeta gráfica de rendimiento #{index}",
        description: "Anuncio generado para comprobar que la página no tiene consultas N+1.",
        price_cents: 10_000 + (index * 1_000),
        condition: index.even? ? :used_like_new : :used_good,
        status: :published,
        published_at: index.minutes.ago,
        quantity: 1,
        country_code: "ES",
        region: regions(:madrid),
        city: "Madrid",
        specs: { "cpu_brand" => index.even? ? "intel" : "amd" }
      )
    end
  end

  test "category page renders 24 listings with fewer than 25 SQL queries" do
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if payload[:name] == "SCHEMA"
      next if sql.match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)

      queries << sql
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get "/es/c/components/graphics-cards"
    end

    assert_response :success
    assert_select "article", minimum: 24
    assert_operator queries.size, :<, 25,
                    "Expected fewer than 25 SQL queries, got #{queries.size}:\n" \
                    "#{queries.map { |sql| sql.first(120) }.join("\n")}"
  end
end
