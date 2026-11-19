require "test_helper"

class FilterDefinitionTest < ActiveSupport::TestCase
  test "option_values lists active options only" do
    assert_equal %w[amd nvidia], filter_definitions(:gpu_chipset).option_values
  end

  test "key format" do
    [ "Bad-Key", "key!", "1key", "_leading", "" ].each do |key|
      definition = FilterDefinition.new(key: key, label_translations: { "en" => "X" })

      assert_not definition.valid?, "#{key} should be rejected"
    end

    assert FilterDefinition.new(key: "cpu_socket_v2", label_translations: { "en" => "X" }).valid?
  end

  test "selection_like? covers checkbox-style inputs" do
    assert_predicate filter_definitions(:gpu_chipset), :selection_like?
    assert_predicate filter_definitions(:console_platform), :selection_like?
    assert_not filter_definitions(:rgb_lighting).selection_like?
  end

  test "label and group fall back to English" do
    definition = filter_definitions(:gpu_chipset)

    assert_equal "Marca de GPU", I18n.with_locale(:es) { definition.label }
    assert_equal "GPU brand", I18n.with_locale(:fr) { definition.label }
  end

  test "input_type default is multi_select" do
    assert_predicate FilterDefinition.new(key: "x_test", label_translations: { "en" => "X" }), :multi_select?
  end
end
