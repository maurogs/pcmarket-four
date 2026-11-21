import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.resize()
  }

  submitOnEnter(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return

    event.preventDefault()
    this.element.requestSubmit()
  }

  resize() {
    const input = this.inputTarget
    input.style.height = "auto"
    input.style.height = `${Math.min(input.scrollHeight, 160)}px`
  }
}
