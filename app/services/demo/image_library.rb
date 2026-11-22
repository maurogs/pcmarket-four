require "digest"
require "fileutils"
require "json"
require "securerandom"
require "uri"

module Demo
  # Downloads and caches openly licensed stock photos for the demo seed.
  #
  # The manifest is committed so a fresh checkout can attribute every photo,
  # while the resized files under storage/demo_images are disposable. Openverse
  # is keyless; Unsplash, Pexels and Pixabay are used only when their API key is
  # configured.
  class ImageLibrary
    USER_AGENT = "PCMarketDemoSeeder/1.0".freeze
    MIN_WIDTH = 800
    MAX_LONGEST_SIDE = 1600
    JPEG_QUALITY = 82
    MAX_CONCURRENT = 2
    POLITE_DELAY = 0.3
    TARGET_MIN = 8
    TARGET_MAX = 15
    DEFAULT_TARGET = 10

    OPENVERSE_URL = "https://api.openverse.org/v1/images/".freeze
    UNSPLASH_URL = "https://api.unsplash.com/search/photos".freeze
    PEXELS_URL = "https://api.pexels.com/v1/search".freeze
    PIXABAY_URL = "https://pixabay.com/api/".freeze

    OPENVERSE_LICENSES = %w[cc0 pdm by by-sa].freeze
    IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze
    SOURCE_LICENSES = {
      "Openverse" => "https://creativecommons.org/licenses/",
      "Unsplash" => "https://unsplash.com/license",
      "Pexels" => "https://www.pexels.com/license/",
      "Pixabay" => "https://pixabay.com/service/license-summary/"
    }.freeze

    # Every query maps to one or more leaf category slugs.
    QUERY_CATEGORIES = {
      "gaming pc rgb" => %w[gaming-pcs streaming-rigs],
      "custom pc build" => %w[gaming-pcs creator-rigs local-ai-rigs],
      "white gaming pc" => %w[gaming-pcs],
      "graphics card" => %w[gpus],
      "nvidia graphics card" => %w[gpus],
      "computer processor cpu" => %w[cpus],
      "motherboard" => %w[motherboards motherboard-bundles],
      "ram memory module" => %w[memory],
      "ssd drive" => %w[storage],
      "pc case" => %w[cases],
      "power supply unit computer" => %w[power-supplies],
      "cpu cooler" => %w[cpu-coolers],
      "computer monitor" => %w[monitors],
      "mechanical keyboard" => %w[keyboards],
      "gaming mouse" => %w[mice],
      "gaming headset" => %w[headphones],
      "gaming laptop" => %w[gaming-laptops],
      "macbook" => %w[macbooks ultrabooks],
      "smartphone" => %w[android-phones other-phones],
      "iphone" => %w[iphone],
      "android phone" => %w[android-phones],
      "tablet ipad" => %w[ipad android-tablets other-tablets],
      "playstation console" => %w[consoles],
      "xbox controller" => %w[controllers],
      "nintendo switch" => %w[handhelds consoles],
      "retro game console" => %w[retro-consoles retro-handhelds retro-controllers],
      "webcam" => %w[webcams],
      "microphone podcast" => %w[microphones],
      "vr headset" => %w[vr-headsets],
      "desk setup gaming" => %w[desk-accessories art-decor collectibles clothing-gear
                               other-accessories speakers sim-racing expansion-cards
                               network-adapters other-components case-fans external-storage
                               other-peripherals games software ultrabooks other-laptops]
    }.freeze

    Candidate = Struct.new(
      :query, :image_url, :fallback_url, :source, :source_url, :creator,
      :license, :license_url, :width, :height, :download_location,
      keyword_init: true
    )

    class << self
      attr_accessor :manifest_path_override

      def call(**options)
        new(**options).call
      end

      def manifest_path
        return Pathname.new(manifest_path_override) if manifest_path_override.present?

        Rails.root.join("db/seeds/demo/image_manifest.json")
      end

      def storage_root
        Rails.root.join("storage/demo_images")
      end

      def manifest(path = manifest_path)
        return [] unless path.exist?

        parsed = JSON.parse(path.read)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError, Errno::ENOENT
        []
      end

      # Manifest entries referenced by at least one attached blob. Falls back to
      # the whole manifest when no demo listing has images (e.g. placeholder
      # seed) so the credits page still satisfies attribution requirements.
      def used_entries(path = manifest_path)
        all = manifest(path)
        return [] if all.empty?

        urls = ActiveStorage::Blob.where("metadata LIKE ?", "%\"source_url\"%")
                                  .pluck(:metadata)
                                  .filter_map { |raw| metadata_hash(raw)["source_url"] }
                                  .to_set
        used = all.select { |entry| urls.include?(entry["source_url"]) }
        used.presence || all
      end

      def metadata_hash(raw)
        case raw
        when Hash then raw
        when String then JSON.parse(raw)
        else {}
        end
      rescue JSON::ParserError
        {}
      end

      def entries_for(category_slug, path = manifest_path)
        manifest(path).select do |entry|
          Array(entry["categories"]).include?(category_slug.to_s)
        end
      end

      def query_slug(query)
        query.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-?\z/, "")
      end
    end

    attr_reader :entries, :target, :queries, :manifest_file, :image_root

    def initialize(queries: QUERY_CATEGORIES.keys, target: DEFAULT_TARGET,
                   manifest_path: self.class.manifest_path,
                   storage_root: self.class.storage_root, logger: nil)
      @queries = Array(queries)
      @target = target.to_i.clamp(1, TARGET_MAX)
      @manifest_file = Pathname.new(manifest_path)
      @image_root = Pathname.new(storage_root)
      @entries = self.class.manifest(@manifest_file).dup
      @logger = logger || ->(message) { puts message }
      @known_urls = @entries.map { |entry| entry["source_url"] }.compact.to_set
      @known_checksums = @entries.map { |entry| entry["sha256"] }.compact.to_set
    end

    def call
      FileUtils.mkdir_p(image_root)
      queries.each do |query|
        next if existing_for(query).size >= target

        @logger.call("Demo images: #{query}")
        candidates = candidates_for(query)
        downloaded = download_batch(candidates, query)
        @entries.concat(downloaded)
        write_manifest
      end
      write_manifest
      entries
    rescue StandardError => e
      @logger.call("Demo images unavailable (#{e.class}: #{e.message}); using cached manifest.")
      entries
    end

    private

    def existing_for(query)
      entries.select { |entry| entry["query"] == query && file_exists?(entry) }
    end

    def file_exists?(entry)
      image_root.join(entry["query_slug"], entry["file"]).file?
    end

    def candidates_for(query)
      candidates = fetch_openverse(query)
      candidates += fetch_unsplash(query) if ENV["UNSPLASH_ACCESS_KEY"].present? && candidates.size < target
      candidates += fetch_pexels(query) if ENV["PEXELS_API_KEY"].present? && candidates.size < target
      candidates += fetch_pixabay(query) if ENV["PIXABAY_API_KEY"].present? && candidates.size < target
      candidates.uniq { |candidate| candidate.source_url.presence || candidate.image_url }
    end

    def fetch_openverse(query)
      params = {
        "q" => query,
        "license" => OPENVERSE_LICENSES.join(","),
        "page_size" => 20,
        "mature" => "false"
      }
      payload = fetch_json("#{OPENVERSE_URL}?#{URI.encode_www_form(params)}")
      Array(payload["results"]).filter_map do |row|
        build_openverse_candidate(query, row)
      end
    rescue StandardError => e
      @logger.call("  Openverse failed: #{e.class}")
      []
    end

    def build_openverse_candidate(query, row)
      license = row["license"].to_s.downcase
      return unless OPENVERSE_LICENSES.include?(license)

      image_url = row["url"].presence || row["thumbnail"].presence
      return unless supported_image?(image_url)

      width = row["width"].to_i
      return if width.positive? && width < MIN_WIDTH

      Candidate.new(
        query: query,
        image_url: row["url"].presence,
        fallback_url: row["thumbnail"].presence,
        source: "Openverse",
        source_url: row["foreign_landing_url"].presence || row["creator_url"].presence,
        creator: row["creator"].presence || "Unknown",
        license: license_label(license),
        license_url: row["license_url"].presence || openverse_license_url(license),
        width: width,
        height: row["height"].to_i
      )
    end

    def fetch_unsplash(query)
      payload = fetch_json(
        "#{UNSPLASH_URL}?#{URI.encode_www_form(query: query, per_page: 20, orientation: 'landscape')}",
        headers: { "Authorization" => "Client-ID #{ENV['UNSPLASH_ACCESS_KEY']}" }
      )
      Array(payload["results"]).filter_map do |row|
        width = row.dig("width").to_i
        next if width.positive? && width < MIN_WIDTH

        Candidate.new(
          query: query,
          image_url: row.dig("urls", "regular"),
          source: "Unsplash",
          source_url: row.dig("links", "html"),
          creator: row.dig("user", "name").presence || "Unsplash contributor",
          license: "Unsplash License",
          license_url: SOURCE_LICENSES["Unsplash"],
          width: width,
          height: row["height"].to_i,
          download_location: row.dig("links", "download_location")
        )
      end
    rescue StandardError => e
      @logger.call("  Unsplash failed: #{e.class}")
      []
    end

    def fetch_pexels(query)
      payload = fetch_json(
        "#{PEXELS_URL}?#{URI.encode_www_form(query: query, per_page: 20, orientation: 'landscape')}",
        headers: { "Authorization" => ENV["PEXELS_API_KEY"].to_s }
      )
      Array(payload["photos"]).filter_map do |row|
        width = row["width"].to_i
        next if width.positive? && width < MIN_WIDTH

        Candidate.new(
          query: query,
          image_url: row.dig("src", "large"),
          source: "Pexels",
          source_url: row["url"],
          creator: row["photographer"].presence || "Pexels contributor",
          license: "Pexels License",
          license_url: SOURCE_LICENSES["Pexels"],
          width: width,
          height: row["height"].to_i
        )
      end
    rescue StandardError => e
      @logger.call("  Pexels failed: #{e.class}")
      []
    end

    def fetch_pixabay(query)
      payload = fetch_json(
        "#{PIXABAY_URL}?#{URI.encode_www_form(key: ENV['PIXABAY_API_KEY'], q: query,
                                               image_type: 'photo', per_page: 20,
                                               safesearch: 'true')}"
      )
      Array(payload["hits"]).filter_map do |row|
        width = row["imageWidth"].to_i
        next if width.positive? && width < MIN_WIDTH

        Candidate.new(
          query: query,
          image_url: row["largeImageURL"].presence || row["webformatURL"].presence,
          source: "Pixabay",
          source_url: row["pageURL"],
          creator: row["user"].presence || "Pixabay contributor",
          license: "Pixabay Content License",
          license_url: SOURCE_LICENSES["Pixabay"],
          width: width,
          height: row["imageHeight"].to_i
        )
      end
    rescue StandardError => e
      @logger.call("  Pixabay failed: #{e.class}")
      []
    end

    def fetch_json(url, headers: {})
      response = http.headers({ "Accept" => "application/json" }.merge(headers)).get(url)
      raise "HTTP #{response.status}" unless response.status.success?

      JSON.parse(response.to_s)
    end

    def http
      HTTP.timeout(connect: 5, read: 25).headers("User-Agent" => USER_AGENT)
    end

    def supported_image?(url)
      return false if url.blank?

      extension = File.extname(URI.parse(url.to_s).path).downcase
      IMAGE_EXTENSIONS.include?(extension)
    rescue URI::InvalidURIError
      false
    end

    def download_batch(candidates, query)
      queue = Queue.new
      candidates.each { |candidate| queue << candidate }
      results = []
      mutex = Mutex.new

      workers = [ MAX_CONCURRENT, [ candidates.size, 1 ].max ].min
      threads = Array.new(workers) do
        Thread.new do
          loop do
            candidate = begin
              queue.pop(true)
            rescue ThreadError
              break
            end

            entry = download_candidate(candidate, query)
            mutex.synchronize { results << entry } if entry
            sleep POLITE_DELAY
          end
        end
      end
      threads.each(&:join)

      results.uniq { |entry| entry["sha256"] }
             .sort_by { |entry| entry["file"] }
             .first([ target - existing_for(query).size, 0 ].max)
    end

    def download_candidate(candidate, query)
      return if candidate.source_url.present? && @known_urls.include?(candidate.source_url)
      return if candidate.image_url.blank?

      bytes = fetch_bytes(candidate.image_url)
      if bytes.blank? && candidate.fallback_url.present? && candidate.fallback_url != candidate.image_url
        bytes = fetch_bytes(candidate.fallback_url)
      end
      return if bytes.blank?

      checksum = Digest::SHA256.hexdigest(bytes)
      return if @known_checksums.include?(checksum)

      trigger_unsplash_download(candidate.download_location)
      entry = store(candidate, query, bytes, checksum)
      if entry
        @known_urls << entry["source_url"] if entry["source_url"].present?
        @known_checksums << checksum
      end
      entry
    rescue StandardError => e
      @logger.call("  Skipped #{candidate.image_url}: #{e.class}")
      nil
    end

    def fetch_bytes(url)
      response = http.follow.get(url)
      return nil unless response.status.success?

      body = response.to_s
      body.bytesize.between?(1, 25.megabytes) ? body : nil
    rescue StandardError
      nil
    end

    def trigger_unsplash_download(url)
      return if url.blank? || ENV["UNSPLASH_ACCESS_KEY"].blank?

      http.headers("Authorization" => "Client-ID #{ENV['UNSPLASH_ACCESS_KEY']}").get(url)
    rescue StandardError
      nil
    end

    def store(candidate, query, bytes, checksum)
      query_slug = self.class.query_slug(query)
      directory = image_root.join(query_slug)
      FileUtils.mkdir_p(directory)

      image = Vips::Image.new_from_buffer(bytes, "", access: :sequential)
      return nil if image.width < MIN_WIDTH

      image = image.autorot
      longest = [ image.width, image.height ].max
      image = image.resize(MAX_LONGEST_SIDE.to_f / longest) if longest > MAX_LONGEST_SIDE
      image = image.colourspace("srgb")
      image = image.bandjoin([ image ] * (3 - image.bands)) if image.bands < 3

      file = "#{query_slug}-#{format('%02d', existing_for(query).size + 1)}-" \
             "#{candidate.source.downcase}-#{SecureRandom.hex(3)}.jpg"
      image.write_to_file(directory.join(file).to_s, Q: JPEG_QUALITY, strip: true)

      {
        "query" => query,
        "query_slug" => query_slug,
        "file" => file,
        "source" => candidate.source,
        "source_url" => candidate.source_url,
        "creator" => candidate.creator,
        "license" => candidate.license,
        "license_url" => candidate.license_url,
        "width" => image.width,
        "height" => image.height,
        "sha256" => checksum,
        "categories" => QUERY_CATEGORIES.fetch(query, [])
      }
    end

    def write_manifest
      FileUtils.mkdir_p(manifest_file.dirname)
      tmp = Pathname.new(manifest_file.to_s.sub(/\.json\z/, ".json.tmp"))
      tmp.write("#{JSON.pretty_generate(entries.sort_by { |entry| [ entry['query'], entry['file'] ] })}\n")
      FileUtils.mv(tmp.to_s, manifest_file.to_s)
    end

    def license_label(license)
      {
        "cc0" => "CC0 1.0",
        "pdm" => "Public Domain Mark 1.0",
        "by" => "CC BY",
        "by-sa" => "CC BY-SA"
      }.fetch(license, license.upcase)
    end

    def openverse_license_url(license)
      case license
      when "cc0" then "https://creativecommons.org/publicdomain/zero/1.0/"
      when "pdm" then "https://creativecommons.org/publicdomain/mark/1.0/"
      when "by" then "https://creativecommons.org/licenses/by/4.0/"
      when "by-sa" then "https://creativecommons.org/licenses/by-sa/4.0/"
      else SOURCE_LICENSES["Openverse"]
      end
    end
  end
end
