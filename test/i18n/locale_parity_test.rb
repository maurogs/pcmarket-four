require "test_helper"
require "yaml"

class LocaleParityTest < ActiveSupport::TestCase
  LOCALES = %w[es en fr de it pt].freeze

  test "every Spanish locale key exists in all other locales" do
    Dir[Rails.root.join("config/locales/*.es.yml")].sort.each do |spanish_path|
      domain = File.basename(spanish_path, ".es.yml")
      spanish_keys = keys_for(spanish_path, "es")

      assert_operator spanish_keys.size, :>, 0, "#{domain} has no Spanish keys"

      LOCALES.each do |locale|
        path = Rails.root.join("config/locales/#{domain}.#{locale}.yml")
        assert File.exist?(path), "Missing locale file #{path}"

        locale_keys = keys_for(path, locale)
        missing = spanish_keys - locale_keys

        assert_empty missing,
                     "#{domain}.#{locale}.yml is missing keys: #{missing.sort.join(', ')}"
      end
    end
  end

  test "no locale has blank translations" do
    Dir[Rails.root.join("config/locales/*.{es,en,fr,de,it,pt}.yml")].sort.each do |path|
      locale = File.basename(path).split(".").second
      data = YAML.load_file(path)&.fetch(locale, {})
      blank_keys = flatten(data).select { |_key, value| value.nil? || value.to_s.strip.empty? }.keys

      assert_empty blank_keys, "#{File.basename(path)} has blank translations: #{blank_keys.join(', ')}"
    end
  end

  private

  def keys_for(path, locale)
    flatten(YAML.load_file(path).fetch(locale, {})).keys
  end

  def flatten(hash, prefix = nil, result = {})
    hash.each do |key, value|
      path = [ prefix, key ].compact.join(".")
      if value.is_a?(Hash)
        flatten(value, path, result)
      else
        result[path] = value
      end
    end
    result
  end
end
