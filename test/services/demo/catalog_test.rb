require "test_helper"

module Demo
  class CatalogTest < ActiveSupport::TestCase
    test "every catalogue and generated PC title is valid for a listing" do
      products = Catalog.catalogue_products

      assert_operator products.size, :>, 150

      products.each do |category_slug, product|
        category = Category.new(
          slug: category_slug,
          names: { "es" => category_slug.tr("-", " ").capitalize }
        )
        title = Seed.title_for(product, category)
        listing = Listing.new(title: title)
        listing.valid?

        assert_operator title.length, :>=, Listing::MIN_TITLE_LENGTH,
                        "#{category_slug} title is too short: #{title.inspect}"
        assert_operator title.length, :<=, Listing::MAX_TITLE_LENGTH,
                        "#{category_slug} title is too long: #{title.inspect}"
        assert_empty listing.errors[:title],
                     "#{category_slug} title is invalid: #{title.inspect} " \
                     "(#{listing.errors[:title].join(', ')})"
      end
    end

    test "short catalogue names get a natural qualifier instead of the condition" do
      category = Category.new(slug: "cases", names: { "es" => "Cajas y chasis" })

      title = Seed.title_for({ title: "Antec C8", brand: "Antec" }, category)

      assert_operator title.length, :>=, Listing::MIN_TITLE_LENGTH
      assert_includes title, "Cajas y chasis"
      assert_not_includes title, "como nuevo"
      assert_not_includes title, "·"
    end
  end
end
