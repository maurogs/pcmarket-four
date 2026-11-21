require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "name falls back to Spanish and then English" do
    category = categories(:cpus)

    assert_equal "Processors", category.name(:en)
    assert_equal "Procesadores", category.name(:es)
    assert_equal "Procesadores", category.name(:xx)
  end

  test "roots_ordered returns root categories in position order" do
    assert_equal [ categories(:components), categories(:laptops) ], Category.roots_ordered.to_a
  end

  test "effective_filters merges ancestor and own active filters" do
    filters = categories(:cpus).effective_filters

    assert_includes filters, filter_definitions(:cpu_brand)
    assert_includes filters, filter_definitions(:vram)
    assert_not_includes filters, filter_definitions(:legacy_filter)
  end

  test "inactive filters are never returned" do
    assert_not_includes categories(:graphics_cards).effective_filters, filter_definitions(:legacy_filter)
  end

  test "leaf? distinguishes parent and child categories" do
    assert categories(:graphics_cards).leaf?
    assert_not categories(:components).leaf?
  end
end
