import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "container" ]

  scroll(event) {
    const direction = Number(event.currentTarget.dataset.direction || 1)
    const amount = Math.max(this.containerTarget.clientWidth * 0.8, 240)
    this.containerTarget.scrollBy({ left: direction * amount, behavior: "smooth" })
  }
}
