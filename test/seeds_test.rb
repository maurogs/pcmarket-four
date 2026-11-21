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

  test "seeds create every legal page for Spain in Spanish and English" do
    load Rails.root.join("db/seeds.rb")

    LegalPage::SLUGS.each do |slug|
      assert LegalPage.published.exists?(slug: slug, country_code: "ES", locale: "es"),
             "missing ES/es #{slug}"
      assert LegalPage.published.exists?(slug: slug, country_code: "ES", locale: "en"),
             "missing ES/en #{slug}"
    end
    assert_equal 18, LegalPage.where(country_code: "ES").count
  end

  test "seeds create the help centre articles" do
    load Rails.root.join("db/seeds.rb")

    assert_equal 18, HelpArticle.published.count
    assert_equal 3, HelpArticle.published.for_category("buying").count
    assert_equal 3, HelpArticle.published.for_category("safety").count
    assert HelpArticle.published.exists?(slug: "how-to-list-an-item")
  end

  test "legal page seeds never overwrite an administrative edit" do
    load Rails.root.join("db/seeds.rb")
    page = LegalPage.find_by!(slug: "terms", country_code: "ES", locale: "es")
    page.update!(body: "<h2>Editado</h2><p>Texto del administrador.</p>",
                 updated_by: users(:admin))

    load Rails.root.join("db/seeds.rb")

    assert_equal "<h2>Editado</h2><p>Texto del administrador.</p>", page.reload.body
    assert_equal users(:admin).id, page.updated_by_id
  end
end
