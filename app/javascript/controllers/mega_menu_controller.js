import { Controller } from "@hotwired/stimulus"

// Desktop mega menu: hover-intent and click open one panel at a time.
// Keyboard support: Left/Right arrows move between top-level triggers
// (keeping the panel open), Down moves into the panel, Escape closes it
// and returns focus to the trigger.
export default class extends Controller {
  static targets = ["item", "trigger", "panel"]
  static values = { hoverDelay: { type: Number, default: 120 }, closeDelay: { type: Number, default: 250 } }

  connect() {
    this.openIndex = null
    this.timers = new Map()
    this.closeOnOutside = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    document.addEventListener("click", this.closeOnOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutside)
    this.timers.forEach((timer) => clearTimeout(timer))
  }

  // Hover intent: open with a small delay, stay open for a moment after
  // the pointer leaves so diagonal mouse moves do not flicker.
  enter(event) {
    this.clearTimer("close")
    const index = this.indexFor(event.currentTarget)
    this.schedule("open", index, () => this.open(index), this.hoverDelayValue)
  }

  leave() {
    this.clearTimer("open")
    this.schedule("close", null, () => this.close(), this.closeDelayValue)
  }

  toggle(event) {
    const index = this.indexFor(event.currentTarget)
    this.openIndex === index ? this.close({ returnFocus: false }) : this.open(index)
  }

  keydown(event) {
    if (event.key === "Escape") {
      if (this.openIndex !== null) {
        this.close({ returnFocus: true })
        event.preventDefault()
      }
      return
    }
    if (event.key === "ArrowDown" && this.openIndex !== null) {
      const first = this.panelTargets[this.openIndex]?.querySelector("a, button")
      if (first) { first.focus(); event.preventDefault() }
      return
    }
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      const triggers = this.triggerTargets
      if (!triggers.includes(document.activeElement)) return
      const step = event.key === "ArrowRight" ? 1 : -1
      const next = triggers[(triggers.indexOf(document.activeElement) + step + triggers.length) % triggers.length]
      next.focus()
      if (this.openIndex !== null) this.open(triggers.indexOf(next))
      event.preventDefault()
    }
  }

  open(index) {
    return if (index ?? -1) < 0
    this.openIndex = index
    this.triggerTargets.forEach((trigger, i) => {
      trigger.setAttribute("aria-expanded", String(i === index))
      trigger.classList.toggle("mega-open", i === index)
    })
    this.panelTargets.forEach((panel, i) => panel.classList.toggle("hidden", i !== index))
  }

  close({ returnFocus = false } = {}) {
    const trigger = this.openIndex === null ? null : this.triggerTargets[this.openIndex]
    this.openIndex = null
    this.triggerTargets.forEach((target) => {
      target.setAttribute("aria-expanded", "false")
      target.classList.remove("mega-open")
    })
    this.panelTargets.forEach((panel) => panel.classList.add("hidden"))
    if (returnFocus) trigger?.focus()
  }

  indexFor(element) {
    return this.itemTargets.indexOf(element.closest("[data-mega-menu-target~='item']"))
  }

  schedule(name, index, callback, delay) {
    this.clearTimer(name)
    this.timers.set(name, setTimeout(() => {
      this.timers.delete(name)
      callback()
    }, delay))
  }

  clearTimer(name) {
    const timer = this.timers.get(name)
    if (timer) {
      clearTimeout(timer)
      this.timers.delete(name)
    }
  }
}
