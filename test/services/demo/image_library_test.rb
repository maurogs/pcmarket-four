require "test_helper"
require "tmpdir"

class Demo::ImageLibraryTest < ActiveSupport::TestCase
  setup do
    @root = Pathname.new(Dir.mktmpdir("demo-image-library"))
    @manifest = @root.join("image_manifest.json")
    @storage = @root.join("images")
    @jpeg = jpeg_bytes(width: 1200, height: 800, colour: "#0f766e")
  end

  teardown do
    FileUtils.rm_rf(@root)
  end

  test "parses Openverse results and keeps only supported licences" do
    payload = {
      "results" => [
        openverse_result(url: "https://images.example.test/by.jpg", license: "by",
                         width: 1200, creator: "Ada", source: "https://example.test/by"),
        openverse_result(url: "https://images.example.test/nc.jpg", license: "by-nc",
                         width: 1200, creator: "Non Commercial", source: "https://example.test/nc"),
        openverse_result(url: "https://images.example.test/sa.jpg", license: "by-sa",
                         width: 1200, creator: "Grace", source: "https://example.test/sa")
      ]
    }
    stub_request(:get, /api\.openverse\.org\/v1\/images/).to_return(
      body: payload.to_json, headers: { "Content-Type" => "application/json" }
    )
    stub_request(:get, "https://images.example.test/by.jpg")
      .to_return(body: @jpeg, headers: { "Content-Type" => "image/jpeg" })
    stub_request(:get, "https://images.example.test/sa.jpg")
      .to_return(body: jpeg_bytes(width: 1100, height: 700, colour: "#4338ca"),
                 headers: { "Content-Type" => "image/jpeg" })

    entries = library(target: 2).call

    assert_equal 2, entries.size
    assert_equal %w[Ada Grace], entries.map { |entry| entry["creator"] }.sort
    assert_equal "CC BY-SA", entries.find { |entry| entry["creator"] == "Grace" }["license"]
    assert_not entries.any? { |entry| entry["source_url"] == "https://example.test/nc" }
    assert @root.join("contact/contact_gaming-pc-rgb.jpg").file?,
           "expected a labelled contact sheet for the query"
  end

  test "ignores Openverse results narrower than 800 pixels" do
    payload = {
      "results" => [
        openverse_result(url: "https://images.example.test/small.jpg", license: "cc0", width: 400,
                         source: "https://example.test/small"),
        openverse_result(url: "https://images.example.test/wide.jpg", license: "cc0", width: 1200,
                         source: "https://example.test/wide")
      ]
    }
    stub_request(:get, /api\.openverse\.org\/v1\/images/).to_return(
      body: payload.to_json, headers: { "Content-Type" => "application/json" }
    )
    stub_request(:get, "https://images.example.test/wide.jpg")
      .to_return(body: @jpeg, headers: { "Content-Type" => "image/jpeg" })

    entries = library(target: 1).call

    assert_equal 1, entries.size
    assert_equal "https://example.test/wide", entries.first["source_url"]
    assert_requested :get, "https://images.example.test/wide.jpg", times: 1
    assert_not_requested :get, "https://images.example.test/small.jpg"
  end

  test "skips optional providers when their API keys are missing" do
    stub_request(:get, /api\.openverse\.org\/v1\/images/).to_return(
      body: { "results" => [] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    assert_equal [], library(target: 1).call
    assert_not_requested :get, /api\.unsplash\.com/
    assert_not_requested :get, /api\.pexels\.com/
    assert_not_requested :get, /pixabay\.com\/api/
  end

  test "falls back gracefully when the network is unavailable" do
    stub_request(:get, /api\.openverse\.org\/v1\/images/).to_timeout

    assert_nothing_raised { assert_equal [], library(target: 1).call }
    assert_equal [], JSON.parse(@manifest.read)
  end

  test "skips duplicate image checksums" do
    payload = {
      "results" => [
        openverse_result(url: "https://images.example.test/one.jpg", license: "cc0", width: 1200),
        openverse_result(url: "https://images.example.test/two.jpg", license: "cc0", width: 1200)
      ]
    }
    stub_request(:get, /api\.openverse\.org\/v1\/images/).to_return(
      body: payload.to_json, headers: { "Content-Type" => "application/json" }
    )
    stub_request(:get, "https://images.example.test/one.jpg")
      .to_return(body: @jpeg, headers: { "Content-Type" => "image/jpeg" })
    stub_request(:get, "https://images.example.test/two.jpg")
      .to_return(body: @jpeg, headers: { "Content-Type" => "image/jpeg" })

    assert_equal 1, library(target: 2).call.size
  end

  test "rejects results whose titles and tags do not match the query" do
    payload = {
      "results" => [
        openverse_result(url: "https://images.example.test/mountain.jpg", license: "cc0",
                         width: 1200, title: "Mountain landscape at sunset",
                         tags: %w[landscape mountain forest]),
        openverse_result(url: "https://images.example.test/pc.jpg", license: "cc0",
                         width: 1200, title: "Gaming PC with RGB fans", tags: %w[gaming pc rgb])
      ]
    }
    stub_request(:get, /api\.openverse\.org\/v1\/images/).to_return(
      body: payload.to_json, headers: { "Content-Type" => "application/json" }
    )
    stub_request(:get, "https://images.example.test/pc.jpg")
      .to_return(body: @jpeg, headers: { "Content-Type" => "image/jpeg" })

    entries = library(target: 2).call

    assert_equal [ "https://example.test/photo" ], entries.map { |entry| entry["source_url"] }
    assert_not_requested :get, "https://images.example.test/mountain.jpg"
  end

  test "honours the committed image denylist by source url or file name" do
    denylist = @root.join("image_denylist.txt")
    denylist.write("# reviewed photos\nhttps://example.test/blocked\n")
    payload = {
      "results" => [
        openverse_result(url: "https://images.example.test/blocked.jpg", license: "cc0",
                         width: 1200, source: "https://example.test/blocked"),
        openverse_result(url: "https://images.example.test/allowed.jpg", license: "cc0",
                         width: 1200, source: "https://example.test/allowed")
      ]
    }
    stub_request(:get, /api\.openverse\.org\/v1\/images/).to_return(
      body: payload.to_json, headers: { "Content-Type" => "application/json" }
    )
    stub_request(:get, "https://images.example.test/allowed.jpg")
      .to_return(body: @jpeg, headers: { "Content-Type" => "image/jpeg" })

    entries = library(target: 2).call

    assert_equal 1, entries.size
    assert_equal "https://example.test/allowed", entries.first["source_url"]
    assert_not_requested :get, "https://images.example.test/blocked.jpg"
  end

  test "used entries intersect the manifest with blob metadata" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(@jpeg), filename: "used.jpg", content_type: "image/jpeg",
      metadata: { "source_url" => "https://example.test/used", "creator" => "Ada" }
    )
    entries = [
      { "source_url" => "https://example.test/used", "creator" => "Ada" },
      { "source_url" => "https://example.test/unused", "creator" => "Grace" }
    ]
    @manifest.write(JSON.pretty_generate(entries))

    assert_equal [ "Ada" ], Demo::ImageLibrary.used_entries(@manifest).map { |entry| entry["creator"] }
    assert_equal 1, Demo::ImageLibrary.used_entries(@manifest).size
  ensure
    blob&.purge
  end

  private

  def library(target:)
    Demo::ImageLibrary.new(
      queries: [ "gaming pc rgb" ], target: target,
      manifest_path: @manifest, storage_root: @storage,
      denylist_path: @root.join("image_denylist.txt"),
      contact_root: @root.join("contact"),
      logger: ->(_message) { }
    )
  end

  def openverse_result(url:, license:, width:, creator: "Photographer",
                       source: "https://example.test/photo", title: "Gaming PC RGB build",
                       tags: %w[gaming pc rgb])
    {
      "url" => url, "thumbnail" => url, "license" => license, "width" => width,
      "height" => 800, "creator" => creator, "foreign_landing_url" => source,
      "title" => title, "tags" => tags.map { |name| { "name" => name } },
      "license_url" => "https://creativecommons.org/licenses/#{license}/4.0/"
    }
  end

  def jpeg_bytes(width:, height:, colour:)
    image = Vips::Image.black(width, height).colourspace("srgb")
    image = image.bandjoin([ image ] * (3 - image.bands)) if image.bands < 3
    image = image.linear(1, 0).cast(:uchar) if colour == "#000000"
    path = @root.join("fixture-#{SecureRandom.hex(4)}.jpg")
    image.write_to_file(path.to_s, Q: 82)
    path.binread
  end
end
