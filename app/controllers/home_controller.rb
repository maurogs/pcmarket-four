class HomeController < ApplicationController
  def index
    @feed = HomeFeed.new(locale: I18n.locale)
  end
end
