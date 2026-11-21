import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu" ]

  connect() {
    this.boundOutside = this.closeOnOutside.bind(this)
    this.boundEscape = this.closeOnEscape.bind(this)
    document.addEventListener("click", this.boundOutside)
    document.addEventListener("keydown", this.boundEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutside)
    document.removeEventListener("keydown", this.boundEscape)
  }

  toggle(event) {
    event.stopPropagation()
    const open = this.menuTarget.hidden
    this.menuTarget.hidden = !open
    this.element.querySelector("[data-dropdown-trigger]")?.setAttribute("aria-expanded", open.toString())
  }

  close() {
    this.menuTarget.hidden = true
    this.element.querySelector("[data-dropdown-trigger]")?.setAttribute("aria-expanded", "false")
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
