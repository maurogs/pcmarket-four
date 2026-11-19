require "test_helper"

class SettingTest < ActiveSupport::TestCase
  setup { I18n.locale = :en }

  def build_setting(attributes = {})
    Setting.create!({
      key: "probe_#{SecureRandom.hex(6)}",
      value: "true",
      value_type: "boolean",
      group: "general",
      description_key: "settings.descriptions.maintenance_mode"
    }.merge(attributes))
  end

  test "requires a unique key" do
    setting = build_setting(key: "unique_probe")
    duplicate = Setting.new(key: "unique_probe", value_type: "string")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
    assert setting.persisted?
  end

  test "casts values according to value_type" do
    boolean = build_setting(value: "true")
    assert_equal true, boolean.typed_value

    integer = build_setting(value: "12", value_type: "integer")
    assert_equal 12, integer.typed_value

    float = build_setting(value: "2.5", value_type: "float")
    assert_equal 2.5, float.typed_value

    json = build_setting(value: { "en" => "hi" }, value_type: "json")
    assert_equal({ "en" => "hi" }, json.reload.typed_value)
  end

  test "AppSettings.get returns cached values and invalidates on update" do
    setting = build_setting(key: "cache_probe", value: "true")
    assert_equal true, AppSettings.get("cache_probe")

    setting.update!(value: "false")
    assert_equal false, AppSettings.get("cache_probe")
    assert_not AppSettings.enabled?("cache_probe")
  end

  test "AppSettings.get falls back to the default for unknown keys" do
    assert_nil AppSettings.get("definitely_missing_key")
    assert_equal "fallback", AppSettings.get("definitely_missing_key", "fallback")
    assert_equal false, AppSettings.enabled?("definitely_missing_key")
  end

  test "AppSettings.localized reads the current locale from a json value" do
    build_setting(key: "localized_probe", value_type: "json",
                  value: { "en" => "hello", "es" => "hola" })

    assert_equal "hola", I18n.with_locale(:es) { AppSettings.localized("localized_probe") }
    assert_equal "hello", I18n.with_locale(:fr) { AppSettings.localized("localized_probe") }
  end

  test "AppSettings.all is invalidated when a setting is destroyed" do
    setting = build_setting(key: "all_probe", value: "true")
    assert AppSettings.all.key?("all_probe")

    setting.destroy!
    assert_not AppSettings.all.key?("all_probe")
  end
end
