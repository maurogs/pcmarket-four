import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "trigger", "panel" ]

  connect() {
    this.timer = null
    this.openPanel = null
    this.clickedOutside = this.closeOnOutside.bind(this)
    document.addEventListener("click", this.clickedOutside)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("click", this.clickedOutside)
  }

  intent(event) {
    this.schedule(event.currentTarget, 150)
  }

  toggle(event) {
    const trigger = event.currentTarget
    if (this.openPanel === trigger.dataset.panelId) return

    this.closeAll()
    this.show(trigger)
  }

  schedule(trigger, delay) {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.show(trigger), delay)
  }

  scheduleClose() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.closeAll(), 150)
  }

  show(trigger) {
    this.closeAll()
    const panel = this.panelTargets.find(
      (element) => element.dataset.panelId === trigger.dataset.panelId
    )
    if (!panel) return

    panel.hidden = false
    trigger.setAttribute("aria-expanded", "true")
    this.openPanel = trigger.dataset.panelId
  }

  closeAll() {
    this.panelTargets.forEach((panel) => {
      panel.hidden = true
    })
    this.triggerTargets.forEach((trigger) => trigger.setAttribute("aria-expanded", "false"))
    this.openPanel = null
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.closeAll()
  }

  escape(event) {
    if (event.key === "Escape") this.closeAll()
  }
}
