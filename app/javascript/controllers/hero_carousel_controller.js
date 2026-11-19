import { Controller } from "@hotwired/stimulus"

// Home page hero carousel of deals: prev/next buttons, dots and a
// gentle auto-advance that pauses on hover or focus.
export default class extends Controller {
  static targets = ["slide", "dot"]
  static values = { index: { type: Number, default: 0 }, auto: { type: Number, default: 6000 } }

  connect() {
    this.count = this.slideTargets.length
    this.render()
    this.startTimer()
  }

  disconnect() {
    this.stopTimer()
  }

  select(event) {
    this.stopTimer()
    this.indexValue = Number(event.params.index)
  }

  prev() {
    this.indexValue = (this.indexValue - 1 + this.count) % this.count
  }

  next() {
    this.indexValue = (this.indexValue + 1) % this.count
  }

  keydown(event) {
    if (event.key === "ArrowLeft") { event.preventDefault(); this.prev() }
    if (event.key === "ArrowRight") { event.preventDefault(); this.next() }
  }

  pause() { this.stopTimer() }

  resume() { this.startTimer() }

  indexValueChanged() { this.render() }

  startTimer() {
    this.stopTimer()
    if (this.autoValue > 0 && this.count > 1) {
      this.timer = setInterval(() => this.next(), this.autoValue)
    }
  }

  stopTimer() {
    if (this.timer) { clearInterval(this.timer); this.timer = null }
  }

  render() {
    if (this.count === 0) return
    const index = ((this.indexValue % this.count) + this.count) % this.count
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("hidden", i !== index)
      slide.setAttribute("aria-hidden", String(i !== index))
    })
    this.dotTargets.forEach((dot, i) => {
      dot.setAttribute("aria-current", String(i === index))
      dot.classList.toggle("bg-primary-600", i === index)
      dot.classList.toggle("bg-cream-300", i !== index)
    })
  }
}
