import { Controller } from "@hotwired/stimulus"

// Keyboard-accessible dropdown used by the mega menu and the language switcher.
// Triggers use aria-expanded; Escape closes and restores focus.
export default class extends Controller {
  static targets = ["menu", "trigger"]

  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("click", this.close, true)
  }

  disconnect() {
    document.removeEventListener("click", this.close, true)
    document.removeEventListener("keydown", this.onKeydown)
  }

  toggle(event) {
    event.stopPropagation()
    this.open ? this.close() : this.show()
  }

  show() {
    this.open = true
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.onKeydown)
    const focusable = this.menuTarget.querySelector("a, button, input")
    focusable?.focus()
  }

  close(event) {
    if (event && event.type === "click" && this.element.contains(event.target)) return
    if (!this.open) return
    this.open = false
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      this.close()
      this.triggerTarget.focus()
    }
  }
}
