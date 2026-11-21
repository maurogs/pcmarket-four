module Admin
  # Persists a manual ordering for a sibling set. Every id must belong to the
  # same parent, otherwise the whole write is rejected.
  class CategoryPositioner
    def initialize(parent_id:, ordered_ids:)
      @parent_id = parent_id.presence
      @ordered_ids = Array(ordered_ids).map(&:to_i).reject(&:zero?)
    end

    def call
      return false if @ordered_ids.empty?

      categories = Category.where(id: @ordered_ids).to_a
      return false unless categories.size == @ordered_ids.size
      return false unless categories.all? { |category| category.parent_id.to_s == @parent_id.to_s }

      Category.transaction do
        @ordered_ids.each_with_index do |id, index|
          Category.where(id: id).update_all(position: index, updated_at: Time.current)
        end
      end
      MenuBuilder.bust!
      ListingSearch.bust_caches!
      true
    end
  end
end
