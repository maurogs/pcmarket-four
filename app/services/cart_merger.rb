class CartMerger
  def initialize(user:, token:)
    @user = user
    @token = token.to_s
  end

  def call
    return if @user.blank? || @token.blank?

    CartItem.transaction do
      CartItem.where(cart_token: @token).includes(:listing).find_each do |guest_item|
        merge_item(guest_item)
        guest_item.destroy!
      end
    end
  end

  private

  def merge_item(guest_item)
    item = CartItem.find_or_initialize_by(user_id: @user.id, listing_id: guest_item.listing_id)
    stock = guest_item.listing.quantity.to_i
    desired = item.quantity.to_i + guest_item.quantity
    item.quantity = [ [ desired, stock ].min, 1 ].max
    item.save!
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    nil
  end
end
