# Demo marketplace data is created only in development, or explicitly in any
# environment with DEMO_SEED=1 (used by the seed smoke test and staging demos).
if Rails.env.development? || ENV["DEMO_SEED"] == "1"
  Demo::Seed.call
end
