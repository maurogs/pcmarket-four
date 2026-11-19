# This file seeds the development and test databases. It loads every file in
# db/seeds/*.rb in name order; each file is idempotent, so running the seeds
# twice does not duplicate or overwrite data.
#
# `seed_record` finds a row by its natural key and inserts it only when
# missing — persisted rows are never updated back to seed values (admins may
# have edited them).

def seed_record(model, attributes, natural_keys)
  record = model.find_or_initialize_by(attributes.slice(*natural_keys))
  return record if record.persisted?

  record.update!(attributes)
  record
end

# Translation hash for text that is identical in every locale (brand and
# model names, units): { "en" => x, "es" => x, … }.
def same_translations(text)
  I18n.available_locales.map { |locale| [ locale.to_s, text ] }.to_h
end

Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| load(file) }

# Sample data for local development (never in production, never duplicated).
if Rails.env.development? && Country.enabled.any? && ENV.fetch("SEED_SAMPLE", "1") != "0"
  Country.enabled.each do |country|
    Faker::Config.locale = country.default_locale
    5.times do |i|
      User.find_or_create_by!(email: "seller#{i + 1}@#{country.code.downcase}.example.com") do |u|
        u.username = User.generate_username(Faker::Internet.username)
        u.first_name = Faker::Name.first_name
        u.last_name = Faker::Name.last_name
        u.phone = Faker::PhoneNumber.phone_number
        u.country = country
        u.locale = country.default_locale
        u.password = Devise.friendly_token(20)
        u.skip_confirmation!
      end
    end
  end
  Rails.logger.info "Seeded #{User.count} sample users (development only)."
end

unless Rails.env.test?
  puts "Seeds: #{Country.count} countries, #{Setting.count} settings, " \
       "#{Category.count} categories, #{FilterDefinition.count} filter definitions, " \
       "#{FilterOption.count} filter options, #{ProductLabel.count} labels, " \
       "#{SellerTag.count} seller tags."
end
