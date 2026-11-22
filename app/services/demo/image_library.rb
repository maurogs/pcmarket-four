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
    CANDIDATE_BUFFER = 2

    OPENVERSE_URL = "https://api.openverse.org/v1/images/".freeze
    UNSPLASH_URL = "https://api.unsplash.com/search/photos".freeze
    PEXELS_URL = "https://api.pexels.com/v1/search".freeze
    PIXABAY_URL = "https://pixabay.com/api/".freeze

    OPENVERSE_LICENSES = %w[cc0 pdm by by-sa].freeze
    IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze
    PREFERRED_ASPECT_RATIOS = "wide,square".freeze
    CONTACT_THUMBNAIL = 200
    CONTACT_COLUMNS = 4

    NEGATIVE_KEYWORDS = %w[
      screenshot landscape mountain forest lake beach portrait wedding car flower map
      poster advertisement ad ads logo illustration drawing painting minecraft far cry
      gta cosplay people person girl boy man woman
    ].freeze

    # Literal queries are preferred; Openverse treats multi-word queries as an
    # AND, so a broader but still relevant query is used when a literal query
    # cannot produce five usable photos.
    QUERY_FALLBACKS = {
      "computer tower rgb fans" => [ "gaming pc", "computer case" ],
      "pc build inside case" => [ "pc build", "gaming pc" ],
      "geforce graphics card" => [ "graphics card", "nvidia graphics card" ],
      "amd ryzen processor chip" => [ "computer processor", "cpu" ],
      "computer motherboard close up" => [ "motherboard", "computer motherboard" ],
      "ddr4 ram stick" => [ "ram memory", "computer memory" ],
      "nvme ssd m.2" => [ "nvme ssd", "ssd" ],
      "computer case glass" => [ "computer case", "pc case" ],
      "atx power supply" => [ "power supply", "computer power supply" ],
      "cpu fan heatsink" => [ "heatsink", "cpu cooler" ],
      "lcd monitor desk" => [ "computer monitor", "monitor" ],
      "mechanical keyboard keycaps" => [ "mechanical keyboard", "keyboard" ],
      "computer mouse" => [ "mouse", "computer mouse" ],
      "headphones headset" => [ "headphones", "headset" ],
      "laptop computer" => [ "laptop", "notebook computer" ],
      "macbook laptop" => [ "macbook", "apple laptop" ],
      "smartphone" => [ "smartphone", "mobile phone" ],
      "iphone" => [ "iphone", "apple iphone" ],
      "samsung galaxy phone" => [ "android smartphone", "smartphone" ],
      "ipad tablet" => [ "ipad", "tablet" ],
      "playstation 5" => [ "game console", "sony playstation" ],
      "xbox controller" => [ "xbox", "game controller" ],
      "nintendo switch console" => [ "nintendo switch", "handheld console" ],
      "retro game console" => [ "retro console", "game console" ],
      "webcam" => [ "webcam", "camera" ],
      "usb microphone" => [ "microphone", "usb mic" ],
      "vr headset" => [ "vr headset", "virtual reality headset" ],
      "gaming desk setup" => [ "desk setup", "gaming desk" ]
    }.freeze

    POSITIVE_KEYWORDS = {
      "computer tower rgb fans" => [ "gaming pc", "pc tower", "computer tower", "pc case",
                                    "computer case", "rgb", "case fan", "computer fan" ],
      "pc build inside case" => [ "pc build", "custom pc", "gaming pc", "pc case", "computer build" ],
      "geforce graphics card" => [ "geforce", "graphics card", "nvidia", "gpu" ],
      "amd ryzen processor chip" => [ "ryzen", "amd cpu", "processor", "cpu" ],
      "computer motherboard close up" => [ "motherboard", "mainboard" ],
      "ddr4 ram stick" => [ "ddr4", "ddr", "ram", "memory module", "memory stick" ],
      "nvme ssd m.2" => [ "nvme", "ssd", "m.2", "m2" ],
      "computer case glass" => [ "pc case", "computer case", "glass case", "tower" ],
      "atx power supply" => [ "atx", "power supply", "psu" ],
      "cpu fan heatsink" => [ "cpu fan", "cpu cooler", "heatsink", "cpu" ],
      "lcd monitor desk" => [ "monitor", "display", "screen" ],
      "mechanical keyboard keycaps" => [ "keyboard", "keycap", "keycaps", "mechanical" ],
      "computer mouse" => [ "mouse", "mice" ],
      "headphones headset" => [ "headphone", "headphones", "headset" ],
      "laptop computer" => [ "laptop", "notebook" ],
      "macbook laptop" => [ "macbook", "apple laptop", "apple" ],
      "smartphone" => [ "smartphone", "mobile phone", "phone" ],
      "iphone" => [ "iphone", "apple phone" ],
      "samsung galaxy phone" => [ "samsung galaxy", "galaxy phone", "samsung", "android",
                                  "smartphone", "phone" ],
      "ipad tablet" => [ "ipad", "tablet" ],
      "playstation 5" => [ "playstation", "ps5", "sony playstation" ],
      "xbox controller" => [ "xbox controller", "xbox", "gamepad", "controller" ],
      "nintendo switch console" => [ "nintendo switch", "switch console", "nintendo" ],
      "retro game console" => [ "retro console", "game console", "atari", "sega", "nintendo",
                                "retro game" ],
      "webcam" => [ "webcam", "web cam" ],
      "usb microphone" => [ "microphone", "usb mic", "mic" ],
      "vr headset" => [ "vr headset", "virtual reality", "oculus", "quest" ],
      "gaming desk setup" => [ "gaming desk", "desk setup", "battlestation", "desk" ]
    }.freeze
    SOURCE_LICENSES = {
      "Openverse" => "https://creativecommons.org/licenses/",
      "Unsplash" => "https://unsplash.com/license",
      "Pexels" => "https://www.pexels.com/license/",
      "Pixabay" => "https://pixabay.com/service/license-summary/"
    }.freeze

    # Every query maps to one or more leaf category slugs. The queries are
    # deliberately literal so the photos resemble the product being sold.
    QUERY_CATEGORIES = {
      "computer tower rgb fans" => %w[gaming-pcs streaming-rigs creator-rigs local-ai-rigs],
      "pc build inside case" => %w[gaming-pcs creator-rigs local-ai-rigs],
      "geforce graphics card" => %w[gpus],
      "amd ryzen processor chip" => %w[cpus],
      "computer motherboard close up" => %w[motherboards motherboard-bundles],
      "ddr4 ram stick" => %w[memory],
      "nvme ssd m.2" => %w[storage external-storage],
      "computer case glass" => %w[cases],
      "atx power supply" => %w[power-supplies],
      "cpu fan heatsink" => %w[cpu-coolers case-fans],
      "lcd monitor desk" => %w[monitors],
      "mechanical keyboard keycaps" => %w[keyboards],
      "computer mouse" => %w[mice],
      "headphones headset" => %w[headphones],
      "laptop computer" => %w[laptops ultrabooks other-laptops],
      "macbook laptop" => %w[macbooks],
      "smartphone" => %w[android-phones other-phones],
      "iphone" => %w[iphone],
      "samsung galaxy phone" => %w[android-phones],
      "ipad tablet" => %w[ipad android-tablets other-tablets],
      "playstation 5" => %w[consoles],
      "xbox controller" => %w[controllers],
      "nintendo switch console" => %w[handhelds],
      "retro game console" => %w[retro-consoles retro-handhelds retro-controllers],
      "webcam" => %w[webcams],
      "usb microphone" => %w[microphones],
      "vr headset" => %w[vr-headsets],
      "gaming desk setup" => %w[desk-accessories art-decor collectibles clothing-gear
                               other-accessories speakers sim-racing expansion-cards
                               network-adapters other-components games software
                               other-peripherals]
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

      def denylist_path
        Rails.root.join("db/seeds/demo/image_denylist.txt")
      end

      def denylist(path = denylist_path)
        return [] unless path.exist?

        path.readlines.filter_map do |line|
          value = line.strip
          next if value.blank? || value.start_with?("#")

          value
        end
      end

      def denylisted?(entry, path = denylist_path)
        blocked = denylist(path)
        return false if blocked.empty?

        values = [ entry["file"], entry["source_url"] ].compact.map { |value| value.to_s.strip }
        values.any? do |value|
          blocked.any? { |rule| rule == value || rule == File.basename(value) }
        end
      rescue StandardError
        false
      end

      def reject_denylisted(entries, path = denylist_path)
        entries.reject { |entry| denylisted?(entry, path) }
      end

      def manifest(path = manifest_path)
        return [] unless path.exist?

        parsed = JSON.parse(path.read)
        entries = parsed.is_a?(Array) ? parsed : []
        reject_denylisted(entries)
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
                   storage_root: self.class.storage_root,
                   denylist_path: self.class.denylist_path,
                   contact_root: Rails.root.join("tmp/qa"), logger: nil)
      @queries = Array(queries)
      @target = target.to_i.clamp(1, TARGET_MAX)
      @manifest_file = Pathname.new(manifest_path)
      @image_root = Pathname.new(storage_root)
      @denylist_path = Pathname.new(denylist_path)
      @contact_root = Pathname.new(contact_root)
      @entries = self.class.reject_denylisted(self.class.manifest(@manifest_file), @denylist_path).dup
      @logger = logger || ->(message) { puts message }
      @known_urls = @entries.map { |entry| entry["source_url"] }.compact.to_set
      @known_checksums = @entries.map { |entry| entry["sha256"] }.compact.to_set
    end

    def call
      FileUtils.mkdir_p(image_root)
      queries.each do |query|
        if existing_for(query).size < target
          @logger.call("Demo images: #{query}")
          candidates = candidates_for(query)
          downloaded = download_batch(candidates, query)
          @entries.concat(downloaded)
          write_manifest
        end
        write_contact_sheet(query)
      end
      @entries = self.class.reject_denylisted(@entries, @denylist_path)
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
      candidates = []
      seen = Set.new
      needed = [ target * CANDIDATE_BUFFER, target + 1 ].max

      variants_for(query).each do |term|
        [ true, false ].each do |preferred|
          pages = preferred ? [ 1 ] : [ 1, 2 ]
          pages.each do |page|
            openverse_rows(term, preferred: preferred, page: page).each do |row|
              next unless relevant_row?(query, row)

              candidate = build_openverse_candidate(query, row)
              next if candidate.nil?
              next if denylisted_candidate?(candidate)

              key = candidate.source_url.presence || candidate.image_url
              next if key.blank? || seen.include?(key)

              seen << key
              candidates << candidate
            end
            break if candidates.size >= needed
          end
          break if candidates.size >= needed
        end
        break if candidates.size >= needed
      end

      candidates += fetch_unsplash(query) if ENV["UNSPLASH_ACCESS_KEY"].present? && candidates.size < target
      candidates += fetch_pexels(query) if ENV["PEXELS_API_KEY"].present? && candidates.size < target
      candidates += fetch_pixabay(query) if ENV["PIXABAY_API_KEY"].present? && candidates.size < target

      candidates.uniq { |candidate| candidate.source_url.presence || candidate.image_url }
                .reject { |candidate| denylisted_candidate?(candidate) }
    end

    def variants_for(query)
      ([ query ] + Array(QUERY_FALLBACKS[query])).uniq
    end

    def fetch_openverse(query)
      candidates_for(query)
    end

    def openverse_rows(query, preferred:, page:)
      params = {
        "q" => query,
        "license" => OPENVERSE_LICENSES.join(","),
        "page_size" => 20,
        "page" => page,
        "mature" => "false"
      }
      if preferred
        params["category"] = "photograph"
        params["aspect_ratio"] = PREFERRED_ASPECT_RATIOS
      end

      payload = fetch_json("#{OPENVERSE_URL}?#{URI.encode_www_form(params)}")
      Array(payload["results"])
    rescue StandardError => e
      @logger.call("  Openverse failed: #{e.class}")
      []
    end

    def relevant_row?(query, row)
      text = normalise_text([ row["title"], Array(row["tags"]).map { |tag| tag["name"] } ].flatten.join(" "))
      return false if text.blank?

      return false if NEGATIVE_KEYWORDS.any? { |word| word_match?(text, word) }

      positives_for(query).any? { |word| word.include?(" ") ? text.include?(word) : word_match?(text, word) }
    end

    def positives_for(query)
      POSITIVE_KEYWORDS[query] ||
        query.to_s.downcase.split(/[^a-z0-9]+/).reject { |word| word.length < 3 }
    end

    def normalise_text(value)
      value.to_s.downcase.gsub(/\s+/, " ").strip
    end

    def word_match?(text, word)
      text.match?(/\b#{Regexp.escape(word)}\b/)
    end

    def denylisted_candidate?(candidate)
      self.class.denylisted?(
        { "file" => nil, "source_url" => candidate.source_url }, @denylist_path
      )
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
      if entry && self.class.denylisted?(entry, @denylist_path)
        FileUtils.rm_f(image_root.join(entry["query_slug"], entry["file"]))
        entry = nil
      end
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

    def write_contact_sheet(query)
      entries = existing_for(query)
      return if entries.empty?

      FileUtils.mkdir_p(@contact_root)
      tiles = entries.filter_map { |entry| contact_tile(entry) }
      return if tiles.empty?

      sheet = Vips::Image.arrayjoin(tiles, across: CONTACT_COLUMNS, shim: 8,
                                          background: [ 245, 245, 245 ])
      path = @contact_root.join("contact_#{self.class.query_slug(query)}.jpg")
      sheet.write_to_file(path.to_s, Q: 80, strip: true)
      @logger.call("  Contact sheet: #{path}")
    rescue StandardError => e
      @logger.call("  Contact sheet failed for #{query}: #{e.class}: #{e.message}")
    end

    def contact_tile(entry)
      path = image_root.join(entry["query_slug"], entry["file"])
      return nil unless path.file?

      image = Vips::Image.thumbnail(path.to_s, CONTACT_THUMBNAIL)
      image = image.flatten(background: 255) if image.bands > 3
      image = image.colourspace("srgb")
      image = image.bandjoin([ image ] * (3 - image.bands)) if image.bands < 3

      label = Vips::Image.text(entry["file"].to_s, width: CONTACT_THUMBNAIL - 4, height: 30, dpi: 96)
      label = label.bandjoin([ label, label ])
      image.join(label, :vertical)
    end

    def write_manifest
      FileUtils.mkdir_p(manifest_file.dirname)
      filtered = self.class.reject_denylisted(entries, @denylist_path)
      tmp = Pathname.new(manifest_file.to_s.sub(/\.json\z/, ".json.tmp"))
      tmp.write("#{JSON.pretty_generate(filtered.sort_by { |entry| [ entry['query'], entry['file'] ] })}\n")
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
