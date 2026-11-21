# Applies seller form input to a listing: scalar attributes, category-scoped
# specs, image attachments/order and the draft/submit/re-review transitions.
class ListingForm
  ATTRIBUTES = %i[
    category_id title brand model_name_text condition quantity description
    price original_price accepts_offers shipping_available free_shipping
    shipping_price ships_within_days local_pickup region_id city postal_code
    tags
  ].freeze

  attr_reader :listing

  def initialize(listing:, params:, submit: false)
    @listing = listing
    @params = params || {}
    @submit = submit
    @was_published = listing.persisted? && listing.published?
  end

  def save
    ensure_store
    purge_removed_images
    assign_scalars
    listing.specs = filtered_specs
    attach_images
    reorder_images
    return false unless submit_has_image?
    return false unless listing.save

    finalise_status
    true
  end

  def submitted?
    @submitted == true
  end

  def sent_back_for_review?
    @sent_back == true
  end

  private

  def ensure_store
    return if listing.store.present? || listing.user.blank?

    listing.store = listing.user.ensure_store!
  end

  def assign_scalars
    listing.assign_attributes(@params.slice(*ATTRIBUTES))
    assign_tags if @params.key?(:tags)
    listing.quantity = 1 unless listing.store&.professional?
    listing.free_shipping = true if truthy?(@params[:free_shipping])
    listing.shipping_price_cents = 0 if listing.free_shipping? || !listing.shipping_available?
  end

  def assign_tags
    listing.tags = Array(@params[:tags])
                        .map(&:to_s)
                        .select { |tag| Listing::TAGS.include?(tag) }
                        .uniq
                        .first(5)
  end

  def filtered_specs
    category = listing.category
    return {} if category.blank?

    allowed = category.effective_filters.map(&:key)
    raw = @params[:specs]
    return listing.specs if raw.nil?
    return {} unless raw.respond_to?(:to_h)

    raw.to_h.stringify_keys.slice(*allowed).each_with_object({}) do |(key, value), result|
      cleaned = normalise_spec_value(value)
      result[key] = cleaned if cleaned.present?
    end
  end

  def normalise_spec_value(value)
    value = value.reject(&:blank?).join(", ") if value.is_a?(Array)
    value.to_s.strip
  end

  def new_signed_ids
    Array(@params[:images]).reject(&:blank?)
  end

  def remove_attachment_ids
    Array(@params[:remove_image_ids]).reject(&:blank?).map(&:to_i)
  end

  def purge_removed_images
    ids = remove_attachment_ids
    return if ids.empty?

    listing.images.attachments.select { |attachment| ids.include?(attachment.id) }.each(&:purge)
    listing.media_changed = true if @was_published
  end

  def attach_images
    ids = new_signed_ids
    return if ids.empty?

    listing.images.attach(ids)
    listing.media_changed = true if @was_published
  end

  def reorder_images
    attachments = listing.images.attachments.to_a
    return if attachments.size < 2

    order = Array(@params[:image_order]).reject(&:blank?).map(&:to_i)
    return if order.empty?

    sorted = attachments.each_with_index.sort_by do |attachment, index|
      [ order.index(attachment.id) || attachments.size, index ]
    end.map(&:first)

    sorted.each_with_index do |attachment, index|
      blob = attachment.blob
      next if blob.metadata["position"] == index

      blob.metadata["position"] = index
      blob.save!
    end

    if @was_published && sorted.map(&:id) != attachments.map(&:id)
      listing.media_changed = true
    end

    listing.images.reset
  end

  def submit_has_image?
    return true unless @submit
    return true if listing.images.attachments.any?

    listing.errors.add(:images, :required)
    false
  end

  def finalise_status
    if @submit && (listing.draft? || listing.rejected?)
      listing.submit_for_review!
      @submitted = true
    end

    return unless @was_published && listing.requires_re_review?

    listing.send_back_for_review!
    @sent_back = true
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end
end
