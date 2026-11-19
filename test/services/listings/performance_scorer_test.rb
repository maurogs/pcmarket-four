require "test_helper"

module Listings
  class PerformanceScorerTest < ActiveSupport::TestCase
    setup do
      gpu_filter = FilterDefinition.create!(key: "gpu_model", position: 10,
        label_translations: { "en" => "GPU model" })
      cpu_filter = FilterDefinition.create!(key: "cpu_model", position: 11,
        label_translations: { "en" => "CPU model" })
      @gpu = gpu_filter.filter_options.create!(value: "rtx_4070", performance_score: 80,
        label_translations: { "en" => "RTX 4070" })
      @cpu = cpu_filter.filter_options.create!(value: "ryzen_7_5800x", performance_score: 60,
        label_translations: { "en" => "Ryzen 7 5800X" })
    end

    test "gpu score alone when there is no cpu spec" do
      listing = build_listing(specs: { "gpu_model" => [ "rtx_4070" ] })

      assert_equal 80, PerformanceScorer.call(listing)
    end

    test "gpu and cpu are blended with the cpu weight" do
      listing = build_listing(specs: { "gpu_model" => [ "rtx_4070" ], "cpu_model" => [ "ryzen_7_5800x" ] })

      # 80 * 0.7 + 60 * 0.3 = 74
      assert_equal 74, PerformanceScorer.call(listing)
    end

    test "nil without a scored gpu" do
      assert_nil PerformanceScorer.call(build_listing)
      assert_nil PerformanceScorer.call(build_listing(specs: { "cpu_model" => [ "ryzen_7_5800x" ] }))

      @gpu.update!(performance_score: nil)
      assert_nil PerformanceScorer.call(build_listing(specs: { "gpu_model" => [ "rtx_4070" ] }))
    end

    test "listing gets the score assigned when specs change" do
      listing = create_listing(specs: { "gpu_model" => [ "rtx_4070" ], "cpu_model" => [ "ryzen_7_5800x" ] })

      assert_equal 74, listing.performance_score

      listing.update!(specs: { "gpu_model" => [ "rtx_4070" ] })
      assert_equal 80, listing.performance_score

      listing.update!(specs: {})
      assert_nil listing.reload.performance_score
    end
  end
end
