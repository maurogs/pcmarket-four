class SellToUsController < ApplicationController
  before_action :require_flag

  def show; end

  private

  def require_flag
    raise ActiveRecord::RecordNotFound unless AppSettings.enabled?(:sell_to_us_enabled)
  end
end
