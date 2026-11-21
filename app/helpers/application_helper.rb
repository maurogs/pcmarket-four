module ApplicationHelper
  include Pagy::Frontend

  BUTTON_BASE = "inline-flex items-center justify-center gap-2 rounded-full font-medium " \
                "transition duration-150 ease-out disabled:pointer-events-none disabled:opacity-50 " \
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 " \
                "focus-visible:ring-offset-2 focus-visible:ring-offset-slate-50 " \
                "dark:focus-visible:ring-offset-zinc-950"

  BUTTON_VARIANTS = {
    primary: "bg-brand-700 text-white shadow-sm hover:bg-brand-800 active:bg-brand-900",
    accent: "bg-accent-500 text-slate-950 shadow-sm hover:bg-accent-400 active:bg-accent-600",
    outline: "border border-slate-300 bg-white text-slate-800 hover:border-brand-500 " \
             "hover:text-brand-700 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100 " \
             "dark:hover:border-brand-400 dark:hover:text-brand-300",
    ghost: "text-slate-700 hover:bg-slate-100 hover:text-slate-950 " \
           "dark:text-zinc-300 dark:hover:bg-zinc-800 dark:hover:text-white",
    danger: "bg-rose-600 text-white shadow-sm hover:bg-rose-700 active:bg-rose-800"
  }.freeze

  BUTTON_SIZES = {
    sm: "min-h-9 px-3 text-sm",
    md: "min-h-11 px-4 text-sm",
    lg: "min-h-12 px-6 text-base"
  }.freeze

  BADGE_TONES = {
    neutral: "bg-slate-100 text-slate-700 dark:bg-zinc-800 dark:text-zinc-200",
    brand: "bg-brand-100 text-brand-800 dark:bg-brand-900/40 dark:text-brand-200",
    accent: "bg-accent-100 text-accent-700 dark:bg-accent-500/15 dark:text-accent-300",
    success: "bg-emerald-100 text-emerald-800 dark:bg-emerald-500/15 dark:text-emerald-300",
    danger: "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300",
    dark: "bg-slate-900 text-white dark:bg-white dark:text-zinc-900"
  }.freeze

  def icon(name, **options)
    @icon_cache ||= {}
    path = Rails.root.join("app/assets/images/icons", "#{name}.svg")
    return "".html_safe unless File.exist?(path)

    svg = @icon_cache[name.to_s] ||= File.read(path).sub(' aria-hidden="true"', "")
    classes = ERB::Util.html_escape(options.fetch(:class, "size-5"))
    title = options[:title]
    if title.present?
      label = ERB::Util.html_escape(title)
      svg.sub("<svg ", %(<svg class="#{classes}" role="img" aria-label="#{label}" focusable="false" ))
    else
      svg.sub("<svg ", %(<svg class="#{classes}" aria-hidden="true" focusable="false" ))
    end.html_safe
  end

  def icon_available?(name)
    name.present? && File.exist?(Rails.root.join("app/assets/images/icons", "#{name}.svg"))
  end

  def site_name
    Setting.get("site_name", "PCMarket")
  end

  def ui_button_classes(variant: :primary, size: :md, extra: nil)
    [ BUTTON_BASE, BUTTON_VARIANTS.fetch(variant, BUTTON_VARIANTS[:primary]),
      BUTTON_SIZES.fetch(size, BUTTON_SIZES[:md]), extra ].compact.join(" ")
  end

  def ui_badge_classes(tone: :neutral, extra: nil)
    [ "inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-medium",
      BADGE_TONES.fetch(tone, BADGE_TONES[:neutral]), extra ].compact.join(" ")
  end

  def ui_chip_classes(active: false, extra: nil)
    classes = if active
      "border-brand-600 bg-brand-700 text-white"
    else
      "border-slate-200 bg-white text-slate-700 hover:border-brand-400 " \
        "hover:text-brand-700 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-300 " \
        "dark:hover:border-brand-500 dark:hover:text-brand-300"
    end
    [ "inline-flex min-h-9 items-center gap-1.5 rounded-full border px-3 py-1.5 " \
      "text-sm font-medium transition", classes, extra ].compact.join(" ")
  end

  def ui_card_classes(extra: nil)
    [ "surface", extra ].compact.join(" ")
  end

  def ui_input_classes(extra = nil)
    [ "min-h-11 w-full rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 " \
      "text-sm text-slate-900 placeholder:text-slate-400 " \
      "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/40 " \
      "dark:border-zinc-700 dark:bg-zinc-900 dark:text-white dark:placeholder:text-zinc-500", extra ].compact.join(" ")
  end

  def format_price(cents)
    amount = cents.to_i / 100.0
    precision = (cents.to_i % 100).zero? ? 0 : 2
    number_to_currency(amount, unit: "€", precision: precision)
  end

  def discount_percent(listing)
    return nil if listing.original_price_cents.blank?
    return nil unless listing.original_price_cents.to_i > listing.price_cents.to_i

    (((listing.original_price_cents - listing.price_cents) * 100.0) / listing.original_price_cents).round
  end

  def listing_condition_label(listing)
    t("activerecord.attributes.listing.condition.#{listing.condition}")
  end

  def listing_condition_tone(listing)
    case listing.condition
    when "new_sealed", "new_open_box" then :success
    when "for_parts" then :danger
    else :neutral
    end
  end

  def listing_seller_name(listing)
    listing.store&.name.presence || listing.user&.display_name
  end

  def listing_location(listing)
    location = [ listing.city, listing.region&.name ].compact_blank.uniq.join(", ")
    location.presence || t("listings.card.location_unknown")
  end

  def spec_chips(listing)
    return [] unless %w[gaming-pcs workstations laptops].include?(listing.category.root.slug)

    keys = %w[gpu_model cpu cpu_brand memory_capacity storage_capacity]
    keys.filter_map do |key|
      value = listing.specs[key]
      next if value.blank?

      [ key, Array(value).join(", ") ]
    end.first(4)
  end

  def cart_items_count
    if current_user
      CartItem.where(user_id: current_user.id).sum(:quantity)
    elsif cookies[:cart_token].present?
      CartItem.where(cart_token: cookies[:cart_token]).sum(:quantity)
    else
      0
    end
  end

  def unread_notifications_count
    current_user ? current_user.notifications.unread.count : 0
  end

  def consent_given?(category)
    return true if category.to_sym == :necessary

    cookie_consent.fetch(category.to_s, false)
  end

  def cookie_consent
    @cookie_consent ||= begin
      raw = cookies[:cookie_consent]
      raw.present? ? JSON.parse(raw) : {}
    rescue JSON::ParserError
      {}
    end
  end

  def cookie_consent_saved?
    cookie_consent.present?
  end

  def preferred_theme
    cookies[:theme].presence_in(%w[light dark])
  end

  def locale_switch_url(locale)
    path = url_for(locale: locale, only_path: true)
    query = request.query_parameters.except("locale").to_query
    query.present? ? "#{path}?#{query}" : path
  end

  def locale_display_name(locale)
    t("common.locales.#{locale}", default: locale.to_s.upcase)
  end

  def nav_link_classes(active = false)
    base = "inline-flex min-h-11 items-center gap-1 px-3 text-sm font-medium transition-colors"
    if active
      "#{base} text-brand-700 dark:text-brand-300"
    else
      "#{base} text-slate-700 hover:text-brand-700 dark:text-zinc-300 dark:hover:text-brand-300"
    end
  end

  def current_path_matches?(path)
    request.path == path
  end

  def structured_data
    base = request.base_url
    locale_prefix = "/#{I18n.locale}"
    {
      "@context" => "https://schema.org",
      "@graph" => [
        {
          "@type" => "Organization",
          "@id" => "#{base}/#organization",
          "name" => site_name,
          "url" => base,
          "logo" => "#{base}/icon.png",
          "sameAs" => %w[https://www.instagram.com/ https://www.youtube.com/ https://x.com/]
        },
        {
          "@type" => "WebSite",
          "@id" => "#{base}/#website",
          "name" => site_name,
          "url" => base,
          "inLanguage" => I18n.locale.to_s,
          "publisher" => { "@id" => "#{base}/#organization" },
          "potentialAction" => {
            "@type" => "SearchAction",
            "target" => {
              "@type" => "EntryPoint",
              "urlTemplate" => "#{base}#{locale_prefix}/search?q={search_term_string}"
            },
            "query-input" => "required name=search_term_string"
          }
        }
      ]
    }.to_json
  end
end
