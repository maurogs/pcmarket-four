import { Controller } from "@hotwired/stimulus"

// Listing image gallery: main image with thumbnails, arrow keys, prev/next
// buttons and touch swipe.
export default class extends Controller {
  static targets = ["image", "thumb", "frame"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.count = this.imageTargets.length
    this.render()
  }

  select(event) {
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

  touchstart(event) {
    this.touchX = event.changedTouches[0].clientX
  }

  touchend(event) {
    if (!this.touchX) return
    const delta = event.changedTouches[0].clientX - this.touchX
    if (delta < -40) this.next()
    else if (delta > 40) this.prev()
    this.touchX = null
  }

  indexValueChanged() {
    this.render()
  }

  render() {
    if (this.count === 0) return
    const index = ((this.indexValue % this.count) + this.count) % this.count
    this.imageTargets.forEach((image, i) => image.classList.toggle("hidden", i !== index))
    this.thumbTargets.forEach((thumb, i) => {
      thumb.classList.toggle("ring-2", i === index)
      thumb.classList.toggle("ring-primary-500", i === index)
      thumb.setAttribute("aria-current", String(i === index))
    })
  }
}
