require "test_helper"

# The seed files must be safe to run any number of times (deploy scripts do
# not know whether a table is already populated).
class SeedsIdempotencyTest < ActiveSupport::TestCase
  # Re-loading seed files in one process would warn about redefined
  # top-level constants; that's noise here (a real `db:seed` is a new
  # process), so silence the warning around the load.
  def seed!
    verbose = $VERBOSE
    $VERBOSE = nil
    load Rails.root.join("db/seeds.rb")
  ensure
    $VERBOSE = verbose
  end

  def counts
    {
      Country => Country.count,
      Setting => Setting.count,
      Category => Category.count,
      FilterDefinition => FilterDefinition.count,
      FilterOption => FilterOption.count,
      CategoryFilter => CategoryFilter.count,
      ProductLabel => ProductLabel.count,
      SellerTag => SellerTag.count
    }
  end

  test "running the seeds twice does not change any count" do
    seed!
    before = counts

    seed!
    after = counts

    assert_equal before, after
  end

  test "reference data is complete after seeding" do
    seed!

    assert_equal 6, Country.count
    assert_operator Category.count, :>=, 45
    assert_operator FilterDefinition.count, :>=, 35
    assert_operator FilterOption.count, :>=, 200
    assert_equal 13, ProductLabel.count
    assert_equal 20, SellerTag.count
    assert_empty ProductLabel.where(slug: %w[value mid_range pro_gamer])
    assert_empty SellerTag.where(slug: %w[verified top_rated quick_shipping business])

    # Translations exist for every available locale (fixture categories that
    # share a slug with a seed row are skipped — the seeds leave them alone).
    fixture_slugs = %w[components gpus cpus gaming-pcs]
    Category.where.not(slug: fixture_slugs).find_each do |category|
      I18n.available_locales.each do |locale|
        assert category.name_for(locale).present?, "#{category.slug} has no #{locale} name"
      end
    end
  end

  test "admin edits survive a re-seed" do
    seed!
    Category.find_by!(slug: "gpus").update!(active: false)

    seed!

    assert_not Category.find_by!(slug: "gpus").active?
  end
end
