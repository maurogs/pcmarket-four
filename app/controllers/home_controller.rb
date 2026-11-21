class HomeController < ApplicationController
  def index
    @site_name = Setting.get("site_name")
  end
end
