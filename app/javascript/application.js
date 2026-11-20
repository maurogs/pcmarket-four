// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { start as startActiveStorage } from "@rails/activestorage"
import "controllers"

// Direct uploads for the sell form's Photos section (see
// app/javascript/controllers/image_uploader_controller.js).
startActiveStorage()
