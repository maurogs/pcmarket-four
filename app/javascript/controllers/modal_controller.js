import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    if (event) event.preventDefault()
    this.dialog.showModal()
  }

  close() {
    this.dialog.close()
  }

  backdropClose(event) {
    if (event.target === this.dialog) this.dialog.close()
  }

  get dialog() {
    return this.element.tagName === "DIALOG" ? this.element : this.element.querySelector("dialog")
  }
}
