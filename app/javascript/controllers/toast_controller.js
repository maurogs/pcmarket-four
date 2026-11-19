import { Controller } from "@hotwired/stimulus"

// Flash-message toast: auto-dismisses, plus manual close button.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    clearTimeout(this.timer)
    this.element.classList.add("opacity-0", "translate-y-2")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    setTimeout(() => this.element.remove(), 600)
  }
}
