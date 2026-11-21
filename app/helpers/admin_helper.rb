module AdminHelper
  PAGINATION_LIMITS = [ 25, 50, 100 ].freeze

  ICON_OPTIONS = %w[
    arrow-right arrow-up badge-check bell bookmark check chevron-down chevron-left
    chevron-right chevron-up clock cpu credit-card eye filter flame gamepad-2 gamepad
    gift headset heart home keyboard laptop layout-grid lock mail map-pin menu
    message-circle package plus rotate-ccw search settings shield-check shopping-cart
    sliders-horizontal smartphone sparkles star store sun tablet tag truck user wallet zap
  ].freeze

  def admin_icon_options
    ICON_OPTIONS
  end

  NAV_SECTIONS = [
    { items: [
      { key: "dashboard", label: "admin.nav.dashboard", icon: "layout-grid", path: :admin_root_path },
      { key: "moderation", label: "admin.nav.moderation", icon: "shield-check", path: :admin_moderation_queue_path,
        badge: :pending_moderation }
    ] },
    { title: "admin.nav.sections.marketplace", items: [
      { key: "listings", label: "admin.nav.listings", icon: "tag", path: :admin_listings_path },
      { key: "users", label: "admin.nav.users", icon: "user", path: :admin_users_path },
      { key: "stores", label: "admin.nav.stores", icon: "store", path: :admin_stores_path },
      { key: "orders", label: "admin.nav.orders", icon: "package", path: :admin_orders_path,
        badge: :pending_payments },
      { key: "payments", label: "admin.nav.payments", icon: "credit-card", path: :admin_payments_path,
        badge: :pending_payments },
      { key: "disputes", label: "admin.nav.disputes", icon: "flame", path: :admin_disputes_path,
        badge: :open_disputes },
      { key: "reports", label: "admin.nav.reports", icon: "message-circle", path: :admin_reports_path,
        badge: :open_reports },
      { key: "reviews", label: "admin.nav.reviews", icon: "star", path: :admin_reviews_path },
      { key: "sell_offers", label: "admin.nav.sell_offers", icon: "wallet", path: :admin_sell_offers_path }
    ] },
    { title: "admin.nav.sections.catalogue", items: [
      { key: "categories", label: "admin.nav.categories", icon: "sliders-horizontal", path: :admin_categories_path },
      { key: "filters", label: "admin.nav.filters", icon: "filter", path: :admin_filter_definitions_path },
      { key: "buyback_prices", label: "admin.nav.buyback_prices", icon: "credit-card", path: :admin_buyback_prices_path }
    ] },
    { title: "admin.nav.sections.content", items: [
      { key: "legal_pages", label: "admin.nav.legal_pages", icon: "bookmark", path: :admin_legal_pages_path },
      { key: "games", label: "admin.nav.games", icon: "gamepad-2", path: :admin_games_path },
      { key: "help_articles", label: "admin.nav.help_articles", icon: "message-circle", path: :admin_help_articles_path }
    ] },
    { title: "admin.nav.sections.marketing", items: [
      { key: "newsletter", label: "admin.nav.newsletter", icon: "mail", path: :admin_newsletter_subscribers_path },
      { key: "feature_requests", label: "admin.nav.feature_requests", icon: "zap", path: :admin_feature_requests_path }
    ] },
    { title: "admin.nav.sections.settings", items: [
      { key: "settings", label: "admin.nav.general_settings", icon: "settings", path: :admin_settings_path },
      { key: "countries", label: "admin.nav.countries", icon: "map-pin", path: :admin_countries_path }
    ] },
    { items: [
      { key: "audit_log", label: "admin.nav.audit_log", icon: "clock", path: :admin_audit_logs_path }
    ] }
  ].freeze

  def admin_nav_sections(pending_count, counts = {})
    NAV_SECTIONS.map do |section|
      {
        title: section[:title],
        items: section[:items].map do |item|
          path = if item[:argument]
            public_send(item[:path], item[:argument])
          else
            public_send(item[:path])
          end
          badge = case item[:badge]
          when :pending_moderation then pending_count
          when :open_disputes then counts[:open_disputes]
          when :open_reports then counts[:open_reports]
          when :pending_payments then counts[:pending_payments]
          end
          item.merge(path: path, badge_count: badge)
        end
      }
    end
  end

  def admin_nav_active?(key)
    case key
    when "dashboard" then controller_name == "dashboard"
    when "moderation" then controller_name == "moderation_queue"
    when "listings" then %w[listings listing_approvals listing_rejections bulk_listing_actions].include?(controller_name)
    when "users" then %w[users user_suspensions user_bans user_roles user_confirmations user_password_resets].include?(controller_name)
    when "stores" then %w[stores store_verifications store_vacations].include?(controller_name)
    when "orders" then %w[orders order_payments order_cancellations order_refunds order_emails
                          order_notes order_exports bulk_payments].include?(controller_name)
    when "payments" then controller_name == "payments"
    when "disputes" then %w[disputes dispute_resolutions].include?(controller_name)
    when "reports" then %w[reports bulk_report_actions].include?(controller_name)
    when "reviews" then controller_name == "reviews"
    when "sell_offers" then controller_name == "sell_offers"
    when "audit_log" then controller_name == "audit_logs"
    when "categories" then %w[categories category_positions].include?(controller_name)
    when "buyback_prices" then controller_name == "buyback_prices"
    when "filters" then %w[filter_definitions filter_options filter_option_bulks filter_option_merges filter_option_positions].include?(controller_name)
    when "legal_pages" then controller_name == "legal_pages"
    when "games" then %w[games game_positions].include?(controller_name)
    when "help_articles" then %w[help_articles help_article_positions].include?(controller_name)
    when "newsletter" then %w[newsletter_subscribers newsletter_exports].include?(controller_name)
    when "feature_requests" then %w[feature_requests feature_request_approvals].include?(controller_name)
    when "settings" then controller_name == "settings"
    when "countries" then %w[countries regions].include?(controller_name)
    else controller_path == "admin/placeholders"
    end
  end

  def admin_sort_link(label, key, sort:, direction:, extra: nil)
    active = sort == key
    next_direction = active && direction == "asc" ? "desc" : "asc"
    query = request.query_parameters.merge("sort" => key, "direction" => next_direction)
    classes = "inline-flex items-center gap-1 font-semibold uppercase tracking-wide transition " \
              "hover:text-slate-900 dark:hover:text-white"
    classes += " text-slate-900 dark:text-white" if active
    link_to url_for(query), class: [ classes, extra ].compact.join(" "),
            aria: { sort: active ? (direction == "asc" ? "ascending" : "descending") : "none" } do
      safe_join([
        label,
        icon(active && direction == "asc" ? "chevron-up" : "chevron-down",
             class: "size-3 #{active ? '' : 'opacity-40'}")
      ])
    end
  end

  def admin_sort_arrow(sort, direction, key)
    return "" unless sort == key

    icon(direction == "asc" ? "chevron-up" : "chevron-down", class: "size-3")
  end

  def admin_badge(text, tone: :neutral, extra: nil)
    content_tag(:span, text, class: ui_badge_classes(tone: tone, extra: extra))
  end

  def admin_listing_status_tone(status)
    case status.to_s
    when "published" then :success
    when "pending_review" then :accent
    when "rejected", "archived" then :danger
    when "sold" then :dark
    when "draft", "paused" then :neutral
    else :brand
    end
  end

  def admin_user_status_tone(status)
    case status.to_s
    when "active" then :success
    when "suspended" then :accent
    when "banned" then :danger
    else :neutral
    end
  end

  def admin_role_tone(role)
    case role.to_s
    when "admin" then :dark
    when "moderator" then :brand
    else :neutral
    end
  end

  def admin_order_status_tone(status)
    case status.to_s
    when "paid", "completed" then :success
    when "shipped", "delivered" then :brand
    when "cancelled", "refunded" then :danger
    when "disputed" then :accent
    else :neutral
    end
  end

  def admin_report_status_tone(status)
    case status.to_s
    when "open" then :accent
    when "resolved" then :success
    else :neutral
    end
  end

  def admin_audit_action_label(action)
    t("admin.audit.actions.#{action.to_s.tr('.', '_')}", default: action.to_s.humanize)
  end

  def admin_datetime(time)
    return "—" if time.blank?

    time.strftime("%d %b %Y · %H:%M")
  end

  def admin_date(time)
    return "—" if time.blank?

    time.strftime("%d %b %Y")
  end

  def admin_number(value)
    number_with_delimiter(value.to_i)
  end

  def admin_bytes(bytes)
    number_to_human_size(bytes.to_i)
  end

  def admin_money(cents)
    format_price(cents.to_i)
  end

  def admin_percent_change(change)
    return "—" if change.nil?

    "#{change.positive? ? '+' : ''}#{change}%"
  end

  # Server-rendered line chart with no JavaScript dependency.
  def admin_line_chart(series, title:, height: 180)
    return admin_chart_empty(title) if series.blank?

    width = 640
    padding = 24
    values = series.map(&:last)
    max = [ values.max.to_i, 1 ].max
    step = series.size > 1 ? (width - padding * 2).to_f / (series.size - 1) : 0
    points = series.each_with_index.map do |(_date, value), index|
      x = padding + index * step
      y = height - padding - (value.to_f / max * (height - padding * 2))
      [ x.round(1), y.round(1) ]
    end
    polyline = points.map { |x, y| "#{x},#{y}" }.join(" ")
    area = "#{padding},#{height - padding} #{polyline} #{points.last[0]},#{height - padding}"
    label_dates = [ series.first.first, series.last.first ]

    content_tag(:figure, class: "w-full") do
      safe_join([
        content_tag(:svg, viewBox: "0 0 #{width} #{height}", class: "h-40 w-full",
                          role: "img", "aria-label": title) do
          safe_join([
            content_tag(:title, title),
            grid_lines(width, height, padding),
            content_tag(:polygon, "", points: area, fill: "currentColor", class: "text-brand-500/10"),
            content_tag(:polyline, "", points: polyline, fill: "none", stroke: "currentColor",
                                           "stroke-width": 2.5, "stroke-linejoin": "round",
                                           "stroke-linecap": "round", class: "text-brand-600"),
            points.last(1).map do |x, y|
              content_tag(:circle, "", cx: x, cy: y, r: 3.5, fill: "currentColor", class: "text-brand-600")
            end
          ])
        end,
        content_tag(:figcaption, class: "mt-1 flex justify-between text-[11px] text-slate-500 dark:text-zinc-400") do
          safe_join(label_dates.map { |date| content_tag(:span, admin_date(date)) })
        end
      ])
    end
  end

  def admin_bar_chart(series, title:, height: 180)
    return admin_chart_empty(title) if series.blank?

    width = 640
    padding = 24
    max = [ series.map(&:last).max.to_i, 1 ].max
    gap = 6
    bar_width = (width - padding * 2 - gap * (series.size - 1)).to_f / series.size

    content_tag(:figure, class: "w-full") do
      safe_join([
        content_tag(:svg, viewBox: "0 0 #{width} #{height}", class: "h-40 w-full",
                          role: "img", "aria-label": title) do
          safe_join([
            content_tag(:title, title),
            grid_lines(width, height, padding),
            safe_join(series.each_with_index.map do |(_date, value), index|
              bar_height = value.to_f / max * (height - padding * 2)
              x = padding + index * (bar_width + gap)
              y = height - padding - bar_height
              content_tag(:rect, "", x: x.round(1), y: y.round(1),
                                      width: bar_width.round(1),
                                      height: [ bar_height, 1 ].max.round(1),
                                      rx: 2, fill: "currentColor", class: "text-brand-500")
            end)
          ])
        end,
        content_tag(:figcaption, class: "mt-1 flex justify-between text-[11px] text-slate-500 dark:text-zinc-400") do
          safe_join([
            content_tag(:span, admin_date(series.first.first)),
            content_tag(:span, admin_date(series.last.first))
          ])
        end
      ])
    end
  end

  def admin_horizontal_bars(rows)
    return content_tag(:p, t("admin.dashboard.no_data"),
                       class: "py-6 text-center text-sm text-slate-500 dark:text-zinc-400") if rows.blank?

    max = [ rows.map(&:last).max.to_i, 1 ].max
    content_tag(:ul, class: "space-y-2.5") do
      safe_join(rows.map do |name, count|
        content_tag(:li) do
          safe_join([
            content_tag(:div, class: "flex items-center justify-between gap-3 text-xs") do
              safe_join([
                content_tag(:span, name, class: "truncate font-medium text-slate-700 dark:text-zinc-300"),
                content_tag(:span, admin_number(count), class: "tabular-nums text-slate-500 dark:text-zinc-400")
              ])
            end,
            content_tag(:div, class: "mt-1 h-2 overflow-hidden rounded-full bg-slate-100 dark:bg-zinc-800") do
              content_tag(:div, "", class: "h-full rounded-full bg-brand-600",
                                   style: "width: #{(count.to_f / max * 100).round}%")
            end
          ])
        end
      end)
    end
  end

  def admin_chart_empty(title)
    content_tag(:div, t("admin.dashboard.no_data"),
                class: "flex h-40 items-center justify-center rounded-lg border border-dashed " \
                       "border-slate-200 text-sm text-slate-400 dark:border-zinc-700 dark:text-zinc-500",
                role: "img", "aria-label": title)
  end

  def admin_changeset_rows(changeset)
    changeset.to_h.map do |attribute, values|
      if values.is_a?(Array) && values.size == 2
        [ attribute, values[0], values[1] ]
      else
        [ attribute, nil, values ]
      end
    end
  end

  def admin_truncate(value, length: 80)
    text = value.nil? ? "—" : value.to_s
    text.length > length ? "#{text[0, length]}…" : text
  end

  private

  def grid_lines(width, height, padding)
    safe_join((0..3).map do |index|
      y = padding + (height - padding * 2) * index / 3.0
      content_tag(:line, "", x1: padding, x2: width - padding, y1: y.round(1), y2: y.round(1),
                             stroke: "currentColor", "stroke-width": 1, opacity: 0.12,
                             class: "text-slate-500")
    end)
  end
end
