import { Controller } from "@hotwired/stimulus"

// Live "n / max" character counter next to a text input (the sell form's
// title field). The max comes from the model (Listing::TITLE_MAX_LENGTH).
export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }

  connect() {
    this.refresh()
  }

  refresh() {
    this.countTarget.textContent = `${this.inputTarget.value.length} / ${this.maxValue}`
  }
}
