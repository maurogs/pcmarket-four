require "test_helper"

# Keeps the six locale files in sync: every locale must define exactly the
# same set of translation keys as English.
class I18nKeysTest < ActiveSupport::TestCase
  FILES = Dir[Rails.root.join("config/locales/*.yml")].sort.freeze

  test "there is one locale file per available locale" do
    available = I18n.available_locales.map(&:to_s).sort
    found = FILES.map { |file| File.basename(file, ".yml") }.sort
    assert_equal available, found
  end

  test "all locale files define the same translation keys" do
    reference = nil

    FILES.each do |file|
      basename = File.basename(file, ".yml")
      data = YAML.load_file(file)
      assert_equal [ basename ], data.keys, "#{basename}.yml must have a single root key"

      keys = flatten(data.fetch(basename))
      if reference.nil?
        reference = keys
      else
        missing = reference - keys
        extra = keys - reference
        assert_equal [], missing, "#{basename}.yml is missing keys: #{missing.join(", ")}"
        assert_equal [], extra, "#{basename}.yml has extra keys: #{extra.join(", ")}"
      end
    end

    assert reference.present?, "no locale files found"
  end

  private

  def flatten(hash, prefix = nil)
    hash.sort_by { |key, _| key }.flat_map do |key, value|
      path = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) ? flatten(value, path) : [ path ]
    end
  end
end
