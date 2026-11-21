import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "panel" ]

  select(event) {
    const index = Number(event.currentTarget.dataset.index)
    this.tabTargets.forEach((tab, position) => {
      const active = position === index
      tab.setAttribute("aria-selected", active.toString())
      tab.setAttribute("tabindex", active ? "0" : "-1")
      tab.classList.toggle("border-brand-600", active)
      tab.classList.toggle("text-brand-700", active)
      tab.classList.toggle("dark:text-brand-300", active)
      tab.classList.toggle("border-transparent", !active)
    })
    this.panelTargets.forEach((panel, position) => {
      panel.hidden = position !== index
    })
  }
}
