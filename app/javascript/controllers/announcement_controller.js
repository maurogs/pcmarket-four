import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: { type: String, default: "pcmarket-announcement" } }

  connect() {
    if (this.dismissed) {
      this.element.hidden = true
    } else {
      this.element.hidden = false
    }
  }

  dismiss() {
    try {
      localStorage.setItem(this.keyValue, "1")
    } catch (error) {
      // Ignore storage errors.
    }
    this.element.hidden = true
  }

  get dismissed() {
    try {
      return localStorage.getItem(this.keyValue) === "1"
    } catch (error) {
      return false
    }
  }
}
