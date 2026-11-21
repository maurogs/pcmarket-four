# Seeds are idempotent: running them repeatedly keeps existing records.
# Reference data is split by domain under db/seeds/ and loaded in dependency order.
load Rails.root.join("db/seeds/settings.rb")
load Rails.root.join("db/seeds/countries.rb")
load Rails.root.join("db/seeds/regions.rb")
load Rails.root.join("db/seeds/categories.rb")
load Rails.root.join("db/seeds/filters.rb")
load Rails.root.join("db/seeds/games.rb")
load Rails.root.join("db/seeds/legal_pages.rb")
load Rails.root.join("db/seeds/help_articles.rb")
load Rails.root.join("db/seeds/buyback_prices.rb")
load Rails.root.join("db/seeds/demo.rb")

puts "Seeds ready: #{Country.count} countries, #{Region.count} regions, " \
     "#{Category.count} categories, #{FilterDefinition.count} filters, " \
     "#{FilterOption.count} filter options, #{Game.count} games, " \
     "#{LegalPage.count} legal pages, #{HelpArticle.count} help articles."
