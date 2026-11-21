import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "item", "search", "moreLabel", "lessLabel" ]
  static values = { collapsible: Boolean }
  static LIMIT = 8

  connect() {
    this.expanded = !this.collapsibleValue
    this.searching = false
    this.apply()
  }

  toggle() {
    this.expanded = !this.expanded
    this.apply()
  }

  search() {
    const query = this.searchTarget.value.trim().toLowerCase()
    this.searching = query.length > 0

    this.itemTargets.forEach((item) => {
      item.hidden = this.searching && !item.dataset.searchText.includes(query)
    })
    this.applyLabels()
  }

  apply() {
    this.itemTargets.forEach((item, index) => {
      if (!this.searching) item.hidden = !this.expanded && index >= this.constructor.LIMIT
    })
    this.applyLabels()
  }

  applyLabels() {
    if (!this.hasMoreLabelTarget) return

    this.moreLabelTarget.classList.toggle("hidden", this.expanded)
    this.lessLabelTarget.classList.toggle("hidden", !this.expanded)
  }
}
