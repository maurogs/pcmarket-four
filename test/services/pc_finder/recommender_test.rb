require "test_helper"

module PcFinder
  class RecommenderTest < ActiveSupport::TestCase
    test "uses listing FPS data and marks a build that meets the target as a great fit" do
      pc = create_gaming_pc(gpu: "RTX 4060", price_cents: 90_000,
                            game_fps: { "fortnite" => { "1080p" => 144 } })
      create_gaming_pc(gpu: "RX 6600", price_cents: 110_000)

      result = Recommender.new(games: [ "fortnite" ], resolution: "1080p", fps: 60).results
      row = result.find { |entry| entry.listing_id == pc.id }

      assert row
      assert_equal 100.0, row.performance
      assert_equal "great", row.fit
      assert_equal 144, row.estimated_fps["fortnite"]
    end

    test "falls back to the GPU tier table when a listing has no FPS data" do
      weak = create_gaming_pc(gpu: "RX 6600", price_cents: 40_000)
      strong = create_gaming_pc(gpu: "RTX 5090", price_cents: 190_000)

      results = Recommender.new(games: [ "cyberpunk-2077" ], resolution: "4k", fps: 144).results
      weak_row = results.find { |entry| entry.listing_id == weak.id }
      strong_row = results.find { |entry| entry.listing_id == strong.id }

      assert_operator strong_row.estimated_fps["cyberpunk-2077"], :>, weak_row.estimated_fps["cyberpunk-2077"]
      assert_operator strong_row.performance, :>, weak_row.performance
    end

    test "filters candidates by budget" do
      cheap = create_gaming_pc(gpu: "RTX 4060", price_cents: 75_000)
      create_gaming_pc(gpu: "RTX 4070", price_cents: 95_000)

      results = Recommender.new(games: [ "fortnite" ], budget: "under_800").results

      assert_equal [ cheap.id ], results.map(&:listing_id)
    end

    test "marks low performance as a stretch and exposes the value component" do
      pc = create_gaming_pc(gpu: "RX 6600", price_cents: 85_000,
                            game_fps: { "cyberpunk-2077" => { "1080p" => 30 } })

      row = Recommender.new(games: [ "cyberpunk-2077" ], resolution: "1080p", fps: 144).results.first

      assert_equal pc.id, row.listing_id
      assert_equal "stretch", row.fit
      assert_operator row.performance, :<, 30
      assert_operator row.value, :>=, 0
      assert_operator row.value, :<=, 100
    end

    test "applies case colour, cooling and vibe preferences" do
      matching = create_gaming_pc(gpu: "RTX 4070", price_cents: 100_000,
                                  specs: { "colour" => "White", "cpu_cooler_type" => "AIO" },
                                  tags: [ "minimalist" ])
      create_gaming_pc(gpu: "RTX 4070", price_cents: 100_000,
                       specs: { "colour" => "Black", "cpu_cooler_type" => "Air" },
                       tags: [ "rgb" ])

      results = Recommender.new(games: [ "fortnite" ], case_colour: "white", cooling: "aio",
                                vibes: [ "minimalist" ]).results

      assert_equal [ matching.id ], results.map(&:listing_id)
    end

    test "gpu tier table recognises known models and defaults otherwise" do
      assert_equal 100, Recommender.gpu_tier("NVIDIA RTX 5090 Founders Edition")
      assert_equal 35, Recommender.gpu_tier("RX 6600")
      assert_equal Recommender::DEFAULT_GPU_TIER, Recommender.gpu_tier("Mystery GPU")
    end
  end
end
