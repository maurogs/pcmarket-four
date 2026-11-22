# Cross-origin access for the native apps and any explicitly allowed web
# client. Origins come from API_CORS_ORIGINS (comma separated). No origin is
# allowed by default.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins lambda { |origin, _env|
      ENV.fetch("API_CORS_ORIGINS", "").split(",").map(&:strip).reject(&:blank?).include?(origin)
    }

    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[ETag Cache-Control X-Total-Pages X-Page X-Per-Page],
             max_age: 600
  end
end
