require "erb"

namespace :context do
  desc "Render the Markdown project context into standalone HTML views"
  task html: :environment do
    ContextHtml.render_all
  end
end

module ContextHtml
  module_function

  LABELS ||= {
    "en" => {
      title: "PCMarket — Project Context",
      subtitle: "Architecture, decisions and code map",
      generated: "Generated from",
      updated: "Updated",
      phases: "Phase status",
      toc: "Contents"
    },
    "es" => {
      title: "PCMarket — Contexto del proyecto",
      subtitle: "Arquitectura, decisiones y mapa de código",
      generated: "Generado desde",
      updated: "Actualizado",
      phases: "Estado de las fases",
      toc: "Contenido"
    }
  }.freeze

  FILES ||= {
    "en" => [ "project.md", "project.html" ],
    "es" => [ "project.es.md", "project.es.html" ]
  }.freeze

  def render_all
    FILES.each do |locale, (source, target)|
      markdown = Rails.root.join(".claude/context", source).read
      html = page(markdown, locale)
      Rails.root.join(".claude/context", target).write(html)
      puts "Wrote .claude/context/#{target}"
    end
  end

  def page(markdown, locale)
    labels = LABELS.fetch(locale)
    body, title = markdown_to_html(markdown)
    source = FILES.fetch(locale).first
    <<~HTML
      <!DOCTYPE html>
      <html lang="#{locale}">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{ERB::Util.html_escape(title.presence || labels[:title])}</title>
        <style>#{css}</style>
      </head>
      <body>
        <header class="hero">
          <p class="eyebrow">PCMarket</p>
          <h1>#{ERB::Util.html_escape(title.presence || labels[:title])}</h1>
          <p class="lede">#{labels[:subtitle]}</p>
          <p class="meta">#{labels[:generated]} <code>#{source}</code> · #{labels[:updated]} #{Time.current.strftime("%Y-%m-%d %H:%M")}</p>
        </header>
        <main>#{body}</main>
        <footer>
          <p>#{labels[:title]} · <code>bin/rails context:html</code></p>
        </footer>
      </body>
      </html>
    HTML
  end

  def markdown_to_html(markdown)
    lines = markdown.lines
    output = +""
    title = nil
    section_open = false
    i = 0

    while i < lines.length
      line = lines[i].rstrip
      stripped = line.strip

      if stripped.start_with?("```")
        code = +""
        i += 1
        while i < lines.length && !lines[i].strip.start_with?("```")
          code << lines[i]
          i += 1
        end
        output << "<pre><code>#{ERB::Util.html_escape(code)}</code></pre>\n"
      elsif line.start_with?("# ")
        title = line.sub("# ", "").strip
      elsif line.start_with?("## ")
        output << "</section>\n" if section_open
        heading = line.sub("## ", "").strip
        css_class = section_class(heading)
        badge = section_badge(heading)
        output << %(<section class="card #{css_class}">\n)
        output << %(<h2><span>#{inline(heading)}</span>#{badge}</h2>\n)
        section_open = true
      elsif line.start_with?("### ")
        output << "<h3>#{inline(line.sub("### ", "").strip)}</h3>\n"
      elsif table_start?(lines, i)
        table, i = parse_table(lines, i)
        output << table
        next
      elsif line.start_with?("- ")
        list, i = parse_list(lines, i)
        output << list
        next
      elsif stripped.empty?
        # skip
      else
        paragraph = +""
        while i < lines.length
          candidate = lines[i].rstrip
          break if candidate.strip.empty?
          break if candidate.start_with?("#", "- ", "```")
          break if table_start?(lines, i)

          paragraph << " " unless paragraph.empty?
          paragraph << candidate.strip
          i += 1
        end
        output << "<p>#{inline(paragraph)}</p>\n"
        next
      end

      i += 1
    end

    output << "</section>\n" if section_open
    [ output, title ]
  end

  def table_start?(lines, index)
    line = lines[index].to_s
    return false unless line.strip.start_with?("|")

    separator = lines[index + 1].to_s
    separator.match?(/\A\s*\|?[\s:\-|]+\|?\s*\z/) && separator.include?("-")
  end

  def parse_table(lines, index)
    header = table_cells(lines[index])
    index += 2
    rows = []
    while index < lines.length && lines[index].strip.start_with?("|")
      rows << table_cells(lines[index])
      index += 1
    end

    html = +"<div class=\"table-wrap\"><table>\n<thead><tr>"
    header.each { |cell| html << "<th>#{inline(cell)}</th>" }
    html << "</tr></thead>\n<tbody>\n"
    rows.each do |row|
      html << "<tr>"
      row.each { |cell| html << "<td>#{status_cell(cell)}</td>" }
      html << "</tr>\n"
    end
    html << "</tbody></table></div>\n"
    [ html, index ]
  end

  def table_cells(line)
    line.strip.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip)
  end

  def parse_list(lines, index)
    html = +"<ul>\n"
    current = nil

    while index < lines.length
      line = lines[index].rstrip
      if line.start_with?("- ")
        html << "<li>#{inline(current)}</li>\n" if current
        current = line.sub("- ", "").strip
      elsif line.start_with?("  ") && current && !line.strip.empty?
        current << " " << line.strip
      else
        break
      end
      index += 1
    end
    html << "<li>#{inline(current)}</li>\n" if current
    html << "</ul>\n"
    [ html, index ]
  end

  def section_class(heading)
    normalized = heading.downcase
    return "status" if normalized.include?("status") || normalized.include?("estado")
    return "open-items" if normalized.include?("open items") || normalized.include?("pendientes")
    return "code-map" if normalized.include?("code map") || normalized.include?("mapa de código")

    ""
  end

  def section_badge(heading)
    normalized = heading.downcase
    return badge("Complete", :success) if normalized.include?("status") && !normalized.include?("phase status")
    return badge("Complete", :success) if normalized == "estado" || normalized.include?("fase") && normalized.include?("estado")

    ""
  end

  def status_cell(cell)
    label = cell.to_s.strip
    tone = case label.downcase
    when "complete", "completed", "completada", "completado", "done", "hecho"
      :success
    when "pending", "pendiente", "planned", "planificada", "in progress", "en curso"
      :warn
    else
      nil
    end
    tone ? badge(label, tone) : inline(label)
  end

  def badge(label, tone)
    %(<span class="badge badge-#{tone}">#{ERB::Util.html_escape(label)}</span>)
  end

  def inline(text)
    escaped = ERB::Util.html_escape(text.to_s)
    escaped = escaped.gsub(/`([^`]+)`/, '<code>\1</code>')
    escaped = escaped.gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
    escaped.gsub(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
  end

  def css
    <<~CSS
      :root {
        color-scheme: light dark;
        --bg: #f1f5f9;
        --card: #ffffff;
        --text: #0f172a;
        --muted: #475569;
        --border: #e2e8f0;
        --brand: #0f766e;
        --brand-soft: #ccfbf1;
        --accent: #d97706;
        --code-bg: #f1f5f9;
        --shadow: 0 1px 2px rgba(15, 23, 42, .06), 0 8px 24px rgba(15, 23, 42, .05);
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #09090b;
          --card: #18181b;
          --text: #f4f4f5;
          --muted: #a1a1aa;
          --border: #27272a;
          --brand: #2dd4bf;
          --brand-soft: rgba(20, 184, 166, .12);
          --accent: #fbbf24;
          --code-bg: #111113;
          --shadow: 0 1px 2px rgba(0, 0, 0, .4), 0 12px 32px rgba(0, 0, 0, .25);
        }
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        background: var(--bg);
        color: var(--text);
        font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      }
      .hero {
        max-width: 1080px;
        margin: 0 auto;
        padding: 56px 24px 24px;
      }
      .eyebrow {
        margin: 0 0 8px;
        color: var(--brand);
        font-size: 12px;
        font-weight: 700;
        letter-spacing: .14em;
        text-transform: uppercase;
      }
      .hero h1 {
        margin: 0;
        font-size: clamp(30px, 5vw, 46px);
        line-height: 1.1;
        letter-spacing: -.02em;
      }
      .lede { margin: 12px 0 0; color: var(--muted); font-size: 18px; }
      .meta { margin: 16px 0 0; color: var(--muted); font-size: 13px; }
      main {
        max-width: 1080px;
        margin: 0 auto;
        padding: 8px 24px 64px;
        display: grid;
        gap: 20px;
      }
      .card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 16px;
        padding: 26px 28px;
        box-shadow: var(--shadow);
        overflow: hidden;
      }
      .card.status {
        border-left: 4px solid var(--brand);
        background: linear-gradient(90deg, var(--brand-soft), transparent 45%), var(--card);
      }
      .card.open-items { border-left: 4px solid var(--accent); }
      .card.code-map { border-left: 4px solid var(--muted); }
      h2 {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 10px;
        margin: 0 0 16px;
        font-size: 22px;
        line-height: 1.25;
        letter-spacing: -.01em;
      }
      h3 { margin: 24px 0 8px; font-size: 16px; color: var(--brand); }
      p { margin: 0 0 12px; }
      .card p:last-child { margin-bottom: 0; }
      ul { margin: 0 0 12px; padding-left: 22px; }
      li { margin: 0 0 6px; }
      li::marker { color: var(--brand); }
      code {
        background: var(--code-bg);
        border: 1px solid var(--border);
        border-radius: 6px;
        padding: 1px 5px;
        font: 13px/1.5 ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        overflow-wrap: anywhere;
      }
      pre {
        margin: 12px 0 0;
        padding: 18px;
        overflow: auto;
        background: var(--code-bg);
        border: 1px solid var(--border);
        border-radius: 12px;
      }
      pre code { background: none; border: 0; padding: 0; white-space: pre; }
      .table-wrap { overflow-x: auto; margin: 8px 0 4px; }
      table { width: 100%; border-collapse: collapse; font-size: 14px; }
      th {
        text-align: left;
        padding: 10px 12px;
        background: var(--code-bg);
        border-bottom: 1px solid var(--border);
        font-size: 12px;
        letter-spacing: .06em;
        text-transform: uppercase;
        color: var(--muted);
      }
      td { padding: 10px 12px; border-bottom: 1px solid var(--border); vertical-align: top; }
      tr:last-child td { border-bottom: 0; }
      .badge {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        border-radius: 999px;
        padding: 3px 10px;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: .04em;
        text-transform: uppercase;
        white-space: nowrap;
      }
      .badge-success { background: rgba(16, 185, 129, .16); color: #047857; }
      .badge-warn { background: rgba(245, 158, 11, .18); color: #b45309; }
      @media (prefers-color-scheme: dark) {
        .badge-success { color: #6ee7b7; }
        .badge-warn { color: #fcd34d; }
      }
      a { color: var(--brand); }
      footer {
        max-width: 1080px;
        margin: 0 auto;
        padding: 0 24px 48px;
        color: var(--muted);
        font-size: 13px;
      }
      @media (max-width: 640px) {
        .hero { padding-top: 36px; }
        .card { padding: 20px; border-radius: 14px; }
      }
      @media print {
        body { background: #fff; color: #000; }
        .card { box-shadow: none; break-inside: avoid; }
      }
    CSS
  end
end
