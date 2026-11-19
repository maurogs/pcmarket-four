module IconHelper
  # Inline SVG icon set (stroke style). Add new icons here so views stay clean.
  ICONS = {
    "search" => '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    "heart" => '<path d="M12 20s-7-4.5-9.2-8.6C1.1 8.1 3 4.5 6.4 4.5c2 0 3.3 1.1 4 2.2.7-1.1 2-2.2 4-2.2 3.4 0 5.3 3.6 3.6 6.9C19 15.5 12 20 12 20Z"/>',
    "bell" => '<path d="M6 9a6 6 0 1 1 12 0c0 4 1.5 5.5 2 6H4c.5-.5 2-2 2-6Z"/><path d="M10 19a2 2 0 0 0 4 0"/>',
    "cart" => '<circle cx="9" cy="20" r="1.2"/><circle cx="17" cy="20" r="1.2"/><path d="M4 5h2l2.2 10.4a1 1 0 0 0 1 .6h7.3a1 1 0 0 0 1-.7L20 8H6.5"/>',
    "user" => '<circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/>',
    "globe" => '<circle cx="12" cy="12" r="8"/><path d="M4 12h16M12 4c2.5 2.3 3.8 5 3.8 8s-1.3 5.7-3.8 8c-2.5-2.3-3.8-5-3.8-8s1.3-5.7 3.8-8Z"/>',
    "sun" => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4m11.4-11.4 1.4-1.4"/>',
    "moon" => '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z"/>',
    "menu" => '<path d="M4 7h16M4 12h16M4 17h16"/>',
    "close" => '<path d="m6 6 12 12M18 6 6 18"/>',
    "chevron-down" => '<path d="m6 9 6 6 6-6"/>',
    "arrow-up" => '<path d="M12 20V4m0 0-6 6m6-6 6 6"/>',
    "plus" => '<path d="M12 5v14M5 12h14"/>',
    "tag" => '<path d="M3 12V5a2 2 0 0 1 2-2h7l9 9-9 9-9-9Z"/><circle cx="8" cy="8" r="1.3"/>',
    "image" => '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="1.5"/><path d="m3 17 4.5-4 3.5 3 4-4L21 17"/>',
    "map-pin" => '<path d="M12 21s-6.5-5.6-6.5-10.2a6.5 6.5 0 1 1 13 0C18.5 15.4 12 21 12 21Z"/><circle cx="12" cy="10.5" r="2.3"/>',
    "eye" => '<path d="M2.5 12S6 5.8 12 5.8 21.5 12 21.5 12 18 18.2 12 18.2 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="2.8"/>',
    "verified" => '<path d="m12 2.8 2.2 1.6 2.7-.2.9 2.6 2.3 1.4-.8 2.6.8 2.6-2.3 1.4-.9 2.6-2.7-.2L12 21.4l-2.2-1.6-2.7.2-.9-2.6-2.3-1.4.8-2.6-.8-2.6 2.3-1.4.9-2.6 2.7.2L12 2.8Z"/><path d="m9 12 2 2 4-4"/>',
    "shield" => '<path d="M12 3l8 3v5.5c0 4.6-3.2 8.2-8 9.5-4.8-1.3-8-4.9-8-9.5V6l8-3Z"/><path d="m9 12 2 2 4-4"/>',
    "truck" => '<path d="M2 7h11v9H2zM13 10h4l3 3v3h-7"/><circle cx="6" cy="17.5" r="1.7"/><circle cx="16.5" cy="17.5" r="1.7"/>',
    "clock" => '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.5 2"/>',
    "chevron-left" => '<path d="m15 5-7 7 7 7"/>',
    "chevron-right" => '<path d="m9 5 7 7-7 7"/>',
    "filter" => '<path d="M4 5h16l-6.2 7.2V18l-3.6 2v-7.8L4 5Z"/>',
    "check" => '<path d="m5 13 4 4 10-10"/>',
    "lock" => '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>'
  }.freeze

  SOCIAL_ICONS = {
    "x" => '<path d="M4 4l16 16M20 4 4 20"/>',
    "instagram" => '<rect x="4" y="4" width="16" height="16" rx="4.5"/><circle cx="12" cy="12" r="3.5"/><circle cx="17" cy="7" r=".8" fill="currentColor" stroke="none"/>',
    "youtube" => '<rect x="3" y="6" width="18" height="12" rx="3"/><path d="m10.5 9.5 4.5 2.5-4.5 2.5v-5Z" fill="currentColor" stroke="none"/>',
    "discord" => '<path d="M7.5 8C9 7.4 10.5 7.1 12 7.1s3 .3 4.5.9c1.8 2.5 2.8 5.4 2.9 8.5-1.3 1-2.7 1.7-4.1 2.1l-.9-1.7"/><path d="M9.1 16.9c-1.4-.4-2.8-1.1-4.1-2.1.1-3.1 1.1-6 2.9-8.5"/><circle cx="9.5" cy="13" r="1.1" fill="currentColor" stroke="none"/><circle cx="14.5" cy="13" r="1.1" fill="currentColor" stroke="none"/>'
  }.freeze

  def icon(name, **options)
    svg_tag(ICONS.fetch(name) { raise ArgumentError, "unknown icon: #{name}" }, options)
  end

  def social_icon(name, **options)
    svg_tag(SOCIAL_ICONS.fetch(name) { raise ArgumentError, "unknown social icon: #{name}" }, options)
  end

  private

  def svg_tag(paths, options)
    css_class = options.delete(:class) || "h-5 w-5"
    attributes = {
      viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
      "stroke-width": "1.8", "stroke-linecap": "round", "stroke-linejoin": "round",
      class: css_class, "aria-hidden": true, focusable: "false"
    }.merge(options)

    tag.svg(**attributes) { paths.html_safe } # rubocop:disable Rails/OutputSafety -- ICONS is a static constant
  end
end
