import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggle", "checkbox" ]

  toggleAll(event) {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = event.currentTarget.checked
    })
  }

  changed() {
    if (!this.hasToggleTarget) return
    this.toggleTarget.checked =
      this.checkboxTargets.length > 0 && this.checkboxTargets.every((checkbox) => checkbox.checked)
  }
}
