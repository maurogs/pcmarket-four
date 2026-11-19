class HomeController < ApplicationController
  def index
    @sell_to_us_enabled = AppSettings.enabled?(:sell_to_us_enabled)
    @home = HomePage.new
  end
end
