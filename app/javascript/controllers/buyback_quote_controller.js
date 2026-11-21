import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "kind", "model" ]

  connect() {
    this.filterModels()
  }

  filterModels() {
    if (!this.hasKindTarget || !this.hasModelTarget) return

    const kind = this.kindTarget.value
    let firstVisible = null
    Array.from(this.modelTarget.options).forEach((option) => {
      const visible = !option.dataset.kind || option.dataset.kind === kind
      option.hidden = !visible
      option.disabled = !visible
      if (visible && firstVisible === null) firstVisible = option
    })

    if (firstVisible && this.modelTarget.selectedOptions[0]?.disabled) {
      this.modelTarget.value = firstVisible.value
    }
  }

  submit() {
    this.element.requestSubmit()
  }
}
