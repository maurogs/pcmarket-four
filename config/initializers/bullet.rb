# N+1 / unused eager loading detection (development only).
if defined?(Bullet)
  Rails.application.configure do
    config.after_initialize do
      Bullet.enable = true
      Bullet.bullet_logger = true
      Bullet.console = true
      Bullet.rails_logger = true
      Bullet.unused_eager_loading_enable = false
    end
  end
end
