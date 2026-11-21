require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds can run repeatedly without errors or duplicates" do
    seeds = Rails.root.join("db/seeds.rb")

    assert_nothing_raised { load seeds }
    first_counts = {
      countries: Country.count,
      regions: Region.count,
      categories: Category.count,
      filters: FilterDefinition.count,
      options: FilterOption.count,
      games: Game.count
    }

    assert_nothing_raised { load seeds }

    assert_equal first_counts[:countries], Country.count
    assert_equal first_counts[:regions], Region.count
    assert_equal first_counts[:categories], Category.count
    assert_equal first_counts[:filters], FilterDefinition.count
    assert_equal first_counts[:options], FilterOption.count
    assert_equal first_counts[:games], Game.count
  end

  test "seeds create the complete taxonomy and reference data" do
    load Rails.root.join("db/seeds.rb")

    assert_equal 6, Country.where(code: %w[ES FR GB DE IT PT]).count
    assert Country.find_by!(code: "ES").enabled?
    assert_equal "GBP", Country.find_by!(code: "GB").currency
    assert_operator Region.where(country_code: "ES").count, :>=, 52

    assert_equal "Gaming PCs", Category.find_by!(slug: "gaming-pcs").name(:en)
    assert_equal "components", Category.find_by!(slug: "gpus").parent.slug
    assert_equal %w[components gpus], Category.find_by!(slug: "gpus").path_slugs

    assert FilterDefinition.find_by!(key: "gpu_model").input_select?
    assert_operator FilterDefinition.count, :>=, 43
    assert_operator FilterOption.count, :>=, 300
    assert CategoryFilter.exists?(category: Category.find_by!(slug: "gpus"),
                                 filter_definition: FilterDefinition.find_by!(key: "gpu_model"))

    assert Game.where(slug: "monster-hunter-wilds").exists?
    assert_operator LegalPage.published.count, :>=, 4
  end
end
