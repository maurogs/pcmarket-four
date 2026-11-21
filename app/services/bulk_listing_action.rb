# Applies one whitelisted bulk action to the listings owned by a seller.
class BulkListingAction
  ACTIONS = %w[pause resume delete].freeze

  attr_reader :count

  def initialize(user:, ids:, action:)
    @user = user
    @ids = Array(ids).map(&:to_i).reject(&:zero?)
    @action = action.to_s
    @count = 0
  end

  def call
    return 0 unless ACTIONS.include?(@action)
    return 0 if @ids.empty?

    @user.listings.where(id: @ids).find_each do |listing|
      @count += 1 if perform(listing)
    end
    @count
  end

  private

  def perform(listing)
    case @action
    when "pause" then listing.pause!
    when "resume" then listing.resume!
    when "delete" then remove(listing)
    end
  end

  def remove(listing)
    if listing.order_items.exists?
      listing.update(status: :archived)
    else
      listing.destroy!
    end
    true
  end
end
