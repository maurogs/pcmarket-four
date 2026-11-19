require "test_helper"

class SpanishProvinceTest < ActiveSupport::TestCase
  test "all 52 provinces are loaded" do
    assert_equal 52, SpanishProvince.all.size
    assert_equal "01", SpanishProvince.codes.first
    assert_equal "52", SpanishProvince.codes.last
  end

  test "find and name lookup" do
    assert_equal "08", SpanishProvince.find("08").code

    assert_equal "Barcelona", SpanishProvince.name("08")
    assert_equal "A Coruña", SpanishProvince.name("15", locale: :de)
    assert_equal "99", SpanishProvince.name("99")
  end

  test "options are name/code pairs sorted by name" do
    options = SpanishProvince.options(locale: :en)

    assert_equal 52, options.size
    assert_includes options, [ "Madrid", "28" ]
    assert_equal options.sort_by { |name, _| name }, options
  end
end
