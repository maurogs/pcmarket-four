import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.initial = this.hasToggleTarget ? this.toggleTarget.checked : false
  }

  confirm(event) {
    if (!this.hasToggleTarget) return
    if (!this.toggleTarget.checked || this.initial) return

    const message = this.toggleTarget.dataset.confirmMessage || "Enable maintenance mode?"
    if (!window.confirm(message)) {
      event.preventDefault()
    }
  }
}
