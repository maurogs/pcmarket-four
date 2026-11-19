# Helpers for the browse page (categories + search): sorts, facet inputs and
# the active-filter pills built from the request params.
module BrowseHelper
  # "relevance" is implicit when there is a query — not a selectable option.
  SORT_OPTIONS = %w[best_match newest price_asc price_desc most_watched].freeze

  def sort_options_for_select
    SORT_OPTIONS.map { |value| [ t("browse.sorts.#{value}"), value ] }
  end

  def current_sort
    value = params[:sort].to_s
    SORT_OPTIONS.include?(value) ? value : SORT_OPTIONS.first
  end

  def current_page
    [ params[:page].to_i, 1 ].max
  end

  def browse_page_url(page)
    url_for(request.query_parameters.merge("page" => page))
  end

  # Page numbers with :gap markers for the numbered pagination.
  def pagination_window(pagy, radius: 2)
    pages = (1..pagy.pages).select do |page|
      page == 1 || page == pagy.pages || (page - pagy.page).abs <= radius
    end
    pages.each_with_index.flat_map { |page, index| index.positive? && page - pages[index - 1] > 1 ? [ :gap, page ] : [ page ] }
  end

  def pagination_page_class(page)
    page == current_page ? "btn-primary px-3" : "btn-ghost px-3"
  end

  # --- Sidebar state ------------------------------------------------------

  def facet_checked?(param_key, value)
    Array(params[param_key]).map(&:to_s).include?(value.to_s)
  end

  # Number inputs work in whole currency; params carry cents.
  def euro_value(param_key)
    cents = params[param_key].presence&.to_i
    return nil if cents.nil? || cents.negative?

    format("%.2f", cents / 100.0).delete_suffix("00").delete_suffix(".")
  end

  def format_euros(cents)
    number_to_currency(cents.to_i / 100.0, unit: "€", precision: 2)
  end

  def selected_filter_count
    count = 0
    count += 1 if params[:min_price].present? || params[:max_price].present?
    %w[condition labels seller_tags].each do |key|
      count += Array(params[key]).map(&:to_s).reject(&:blank?).size
    end
    (params[:specs].presence || {}).each_value do |values|
      count += Array(values).map(&:to_s).reject(&:blank?).size
    end
    count
  end

  # --- Active filters -----------------------------------------------------

  # [{ label:, remove_url: }, …] for every filter currently applied.
  def active_filters(result)
    pills = []
    pills << price_pill if params[:min_price].present? || params[:max_price].present?
    Array(params[:condition]).each do |value|
      next unless Listing.conditions.key?(value.to_s.to_sym)

      pills << { label: t("activerecord.attributes.listing.condition.#{value}"),
                 remove_url: filter_removal_url("condition", value: value) }
    end
    pills.concat(named_label_pills("labels", result))
    pills.concat(named_label_pills("seller_tags", result))
    result.selected_filter_options.each do |key, labels|
      labels.each do |value, label|
        pills << { label: label, remove_url: filter_removal_url("specs[#{key}]", value: value) }
      end
    end
    pills
  end

  # Sidebar chip lists, memoized per request (same rows the pills use).
  def selectable_labels(param_key)
    klass = param_key == "labels" ? ProductLabel : SellerTag
    @named_label_lists ||= {}
    @named_label_lists[klass] ||= klass.active.ordered
  end

  def clear_filters_url
    url_for(request.query_parameters.slice("q").compact)
  end

  # Hidden inputs echoing the committed (URL) filter state, for the three
  # browse forms (desktop, mobile, sort) — each edits one slice and must
  # keep the rest of the query intact on submit.
  def hidden_filter_fields(except: [])
    except = Array(except).map(&:to_s)
    fields = []
    fields << hidden_field_tag("q", params[:q].to_s) unless except.include?("q")
    fields << hidden_field_tag("sort", current_sort) unless except.include?("sort")
    %w[min_price max_price].each do |key|
      fields << hidden_field_tag(key, params[key].to_s) if params[key].present? && except.exclude?(key)
    end
    %w[condition labels seller_tags].each do |key|
      next if except.include?(key)

      Array(params[key]).each { |value| fields << hidden_field_tag("#{key}[]", value.to_s) }
    end
    (params[:specs].presence || {}).each do |spec_key, values|
      next if except.include?("specs") || except.include?("specs[#{spec_key}]")

      Array(values).each { |value| fields << hidden_field_tag("specs[#{spec_key}][]", value.to_s) }
    end
    safe_join(fields)
  end

  # URL for this browse page with one or more filter params removed (whole
  # param or a single list value with `value:`). `key` may be plain
  # ("min_price"), a list ("condition") or a spec ("specs[gpu_chipset]").
  def filter_removal_url(*keys, value: nil)
    query = request.query_parameters.deep_dup
    keys.each do |raw_key|
      key = raw_key.to_s
      if key.start_with?("specs[")
        spec_key = key[/\[(.+)\]/, 1]
        specs = query["specs"].to_h
        values = Array(specs[spec_key]) - Array(value).map(&:to_s)
        values.any? ? specs[spec_key] = values : specs.delete(spec_key)
        specs.any? ? query["specs"] = specs : query.delete("specs")
      elsif value
        values = Array(query[key]) - [ value.to_s ]
        values.any? ? query[key] = values : query.delete(key)
      else
        query.delete(key)
      end
    end
    query.delete("page")
    url_for(query)
  end

  private

  def price_pill
    min = params[:min_price].presence&.to_i
    max = params[:max_price].presence&.to_i
    label =
      if min && max
        t("browse.filters.price_between", min: format_euros(min), max: format_euros(max))
      elsif min
        t("browse.filters.price_min", price: format_euros(min))
      else
        t("browse.filters.price_max", price: format_euros(max))
      end
    { label: label, remove_url: filter_removal_url("min_price", "max_price") }
  end

  def named_label_pills(param_key, _result)
    Array(params[param_key]).filter_map do |slug|
      label = named_label_label(param_key, slug)
      next if label.nil?

      { label: label, remove_url: filter_removal_url(param_key, value: slug) }
    end
  end

  def named_label_label(param_key, slug)
    klass = param_key == "labels" ? ProductLabel : SellerTag
    @named_labels ||= {}
    @named_labels[klass] ||= klass.active.index_by(&:slug)
    @named_labels[klass][slug.to_s]&.name
  end
end
