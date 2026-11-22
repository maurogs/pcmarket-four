require "test_helper"
require "tmpdir"

class CreditsPageTest < ActionDispatch::IntegrationTest
  setup do
    @original_override = Demo::ImageLibrary.manifest_path_override
    @root = Pathname.new(Dir.mktmpdir("credits-page"))
  end

  teardown do
    Demo::ImageLibrary.manifest_path_override = @original_override
    FileUtils.rm_rf(@root)
  end

  test "renders creator, source and licence links from the manifest" do
    write_manifest([ {
      "query" => "gaming pc rgb", "file" => "photo.jpg", "source" => "Openverse",
      "source_url" => "https://example.test/photos/one",
      "creator" => "Ada Lovelace", "license" => "CC BY",
      "license_url" => "https://creativecommons.org/licenses/by/4.0/"
    } ])

    get credits_path(locale: :es)

    assert_response :success
    assert_includes response.body, "Ada Lovelace"
    assert_includes response.body, "CC BY"
    assert_select "a[href=?]", "https://example.test/photos/one"
    assert_select "a[href=?]", "https://creativecommons.org/licenses/by/4.0/"
  end

  test "shows an empty state when no demo images are recorded" do
    write_manifest([])

    get credits_path(locale: :en)

    assert_response :success
    assert_includes response.body, I18n.t("demo_credits.empty", locale: :en)
  end

  private

  def write_manifest(entries)
    path = @root.join("image_manifest.json")
    path.write(JSON.pretty_generate(entries))
    Demo::ImageLibrary.manifest_path_override = path
  end
end
