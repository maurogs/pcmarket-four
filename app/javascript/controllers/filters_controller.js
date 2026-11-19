import { Controller } from "@hotwired/stimulus"

// Browse filter form: auto-submits as a GET Turbo Frame navigation on any
// change (debounced), and keeps cents-valued hidden fields in sync with the
// euro price inputs shown to the user.
export default class extends Controller {
  static targets = ["euro"]

  connect() {
    this.debounce = null
    this.euroTargets.forEach((input) => {
      input.hiddenSync = document.createElement("input")
      input.hiddenSync.type = "hidden"
      input.hiddenSync.name = input.dataset.filtersName
      input.hiddenSync.value = this.cents(input)
      input.insertAdjacentElement("afterend", input.hiddenSync)
    })
  }

  disconnect() {
    clearTimeout(this.debounce)
  }

  change() {
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => this.submit(), 350)
  }

  submit() {
    this.element.requestSubmit()
  }

  euroInput(event) {
    const input = event.target
    if (input.hiddenSync) input.hiddenSync.value = this.cents(input)
  }

  cents(input) {
    const value = parseFloat(input.value)
    return Number.isNaN(value) || value <= 0 ? "" : String(Math.round(value * 100))
  }
}
