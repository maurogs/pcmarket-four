import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "slide", "dot" ]
  static values = { interval: { type: Number, default: 6000 } }

  connect() {
    this.index = 0
    this.timer = null
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.show(0)
    this.start()
  }

  disconnect() {
    this.stop()
  }

  next() {
    this.show((this.index + 1) % this.slideTargets.length)
  }

  previous() {
    this.show((this.index - 1 + this.slideTargets.length) % this.slideTargets.length)
  }

  goTo(event) {
    this.show(Number(event.currentTarget.dataset.index))
  }

  pause() {
    this.stop()
  }

  resume() {
    this.start()
  }

  keydown(event) {
    if (event.key === "ArrowRight") this.next()
    if (event.key === "ArrowLeft") this.previous()
  }

  show(index) {
    if (this.slideTargets.length === 0) return

    this.index = index
    this.slideTargets.forEach((slide, position) => {
      slide.hidden = position !== index
    })
    this.dotTargets.forEach((dot, position) => {
      const active = position === index
      dot.setAttribute("aria-selected", active.toString())
      dot.classList.toggle("bg-white", active)
      dot.classList.toggle("bg-white/40", !active)
    })
  }

  start() {
    if (this.reducedMotion || this.slideTargets.length < 2) return
    this.stop()
    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
    this.timer = null
  }
}
