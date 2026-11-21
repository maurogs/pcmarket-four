module Admin
  # Rewrites every listing spec value from one option to another in a single
  # UPDATE, then removes the source option. Used by the option merge screen.
  class FilterOptionMerger
    def initialize(filter_definition, source:, target:)
      @filter_definition = filter_definition
      @source = source.to_s
      @target = target.to_s
    end

    def call
      return false if @source.blank? || @target.blank? || @source == @target
      return false unless @filter_definition.filter_options.exists?(value: @target)

      key = @filter_definition.key
      Listing.transaction do
        Listing.where("specs ->> ? = ?", key, @source).update_all(
          Arel.sql(
            "specs = jsonb_set(specs, ARRAY[#{Listing.connection.quote(key)}], " \
            "to_jsonb(#{Listing.connection.quote(@target)}::text), true), updated_at = NOW()"
          )
        )
        @filter_definition.filter_options.where(value: @source).delete_all
      end
      ListingSearch.bust_caches!
      true
    end
  end
end
