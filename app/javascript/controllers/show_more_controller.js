import { Controller } from "@hotwired/stimulus"

// Reveals the options behind a "show more" cutoff (featured stay visible).
export default class extends Controller {
  static targets = ["more", "button"]

  toggle() {
    const hidden = this.moreTarget.hidden
    this.moreTarget.hidden = !hidden
    this.buttonTarget.textContent = this.element.dataset[hidden ? "expandedLabel" : "collapsedLabel"]
  }
}
