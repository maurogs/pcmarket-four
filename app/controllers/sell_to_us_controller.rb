# GET /sell_to_us — "Sell to us" (instant offer) info page. Behind the
# sell_to_us_enabled flag (default off): when disabled the page and every
# link to it disappear, so a direct hit must 404 as well.
class SellToUsController < ApplicationController
  before_action :require_flag

  def show; end

  private

  def require_flag
    render_not_found unless AppSettings.enabled?(:sell_to_us_enabled)
  end
end
