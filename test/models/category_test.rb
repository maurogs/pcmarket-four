require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "tree helpers walk parents and children" do
    components = categories(:components)

    assert_equal [ categories(:gpus).id, categories(:cpus).id ].sort,
      components.descendant_ids.sort
    assert_equal [ components.id ], categories(:gpus).ancestor_ids
    assert_includes categories(:gpus).self_and_descendant_ids, categories(:gpus).id
    assert_equal 1, categories(:gpus).depth
    assert_equal 0, components.depth
  end

  test "a category cannot become its own descendant" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      categories(:components).update!(parent: categories(:gpus))
    end

    assert_includes error.message, "Parent"
  end

  test "slug is generated from the English name when missing" do
    category = Category.create!(
      kind: :component,
      name_translations: { "en" => "Case Fans", "es" => "Ventiladores de caja" },
      description_translations: {}
    )

    assert_equal "case-fans", category.slug
  end

  test "slug must be snake-ish urls" do
    category = Category.new(slug: "Bad Slug!", kind: :component, name_translations: { "en" => "X" })

    assert_not category.valid?
    assert category.errors[:slug].any?
  end

  test "requires an English name" do
    category = Category.new(kind: :component, name_translations: { "es" => "Sin inglés" })

    assert_not category.valid?
    assert category.errors[:name_translations].any?
  end

  test "effective filters inherit from ancestors" do
    gpus = categories(:gpus)
    keys = gpus.effective_filter_definitions.map(&:key)

    assert_equal %w[cpu_brand gpu_chipset rgb_lighting], keys.sort
    assert_not_includes categories(:components).effective_filter_definitions.map(&:key), "cpu_brand"
  end

  test "inactive definitions are dropped from the effective list" do
    filter_definitions(:gpu_chipset).update_column(:active, false)

    assert_equal %w[cpu_brand rgb_lighting],
      categories(:gpus).effective_filter_definitions.map(&:key).sort
  end

  test "refresh_listings_count! counts published listings including descendants" do
    # Baseline first: the browse fixtures already publish listings under
    # gpus, so assert on a delta.
    Categories::RefreshListingsCount.call(categories(:gpus))
    before = categories(:gpus).reload.listings_count
    publish(create_listing(title: "RTX 3060 Founders Edition", category: categories(:gpus)))
    publish(create_listing(title: "RTX 2060 Super OC", category: categories(:gpus)))
    publish(create_listing(title: "Ryzen 7 5800X Boxed", category: categories(:cpus)))
    create_listing(title: "Core i5 12400F Draft", category: categories(:cpus))

    Categories::RefreshListingsCount.call(categories(:gpus))

    assert_equal before + 2, categories(:gpus).reload.listings_count
    assert_equal 0, categories(:cpus).reload.listings_count
    assert_equal 0, categories(:gaming_pcs).reload.listings_count
  end

  test "publishing a listing queues category and store counter refreshes" do
    listing = create_listing(title: "ASRock RX 7800 XT", category: categories(:gpus))
    clear_enqueued_jobs

    publish(listing)

    assert_enqueued_with(job: Categories::RefreshListingsCountJob, args: [ listing.category_id ])
    assert_enqueued_with(job: Stores::RefreshCountersJob, args: [ listing.store_id ])
  end

  test "a category with listings cannot be destroyed" do
    create_listing(title: "Intel Core i9 14900K", category: categories(:cpus))

    assert_raises(ActiveRecord::DeleteRestrictionError) { categories(:cpus).destroy! }
  end

  test "in_category scope covers descendants" do
    listing = publish(create_listing(title: "Zotac RTX 4060 Twin Edge", category: categories(:gpus)))
    other = publish(create_listing(title: "MSI MAG B650 Tomahawk", category: categories(:cpus)))

    ids = Listing.in_category(categories(:components)).pluck(:id)

    assert_includes ids, listing.id
    assert_includes ids, other.id
    assert_not_includes ids, publish(create_listing(title: "ASUS ROG Strix Z790", category: categories(:gaming_pcs))).id
  end
end
