import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button" ]

  connect() {
    this.scroll = this.update.bind(this)
    window.addEventListener("scroll", this.scroll, { passive: true })
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.scroll)
  }

  update() {
    this.buttonTarget.hidden = window.scrollY < 500
  }

  top() {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}
