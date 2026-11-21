import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "slide", "thumb", "counter", "lightbox", "lightboxImage" ]

  connect() {
    this.index = 0
    this.pointerStart = null
    this.show(0)
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

  show(index) {
    if (this.slideTargets.length === 0) return

    this.index = index
    this.slideTargets.forEach((slide, position) => {
      slide.hidden = position !== index
    })
    this.thumbTargets.forEach((thumb, position) => {
      thumb.setAttribute("aria-current", position === index ? "true" : "false")
      thumb.classList.toggle("ring-2", position === index)
      thumb.classList.toggle("ring-brand-600", position === index)
    })
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${index + 1} / ${this.slideTargets.length}`
    }
  }

  keydown(event) {
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    }
    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.previous()
    }
  }

  pointerDown(event) {
    this.pointerStart = event.clientX
  }

  pointerUp(event) {
    if (this.pointerStart === null) return

    const distance = event.clientX - this.pointerStart
    this.pointerStart = null
    if (Math.abs(distance) < 40) return
    distance < 0 ? this.next() : this.previous()
  }

  openLightbox() {
    if (!this.hasLightboxTarget) return

    const slide = this.slideTargets[this.index]
    const image = slide?.querySelector("img")
    if (image && this.hasLightboxImageTarget) {
      this.lightboxImageTarget.src = image.dataset.fullSrc || image.src
      this.lightboxImageTarget.alt = image.alt
    }
    this.lightboxTarget.showModal()
  }

  closeLightbox() {
    if (this.hasLightboxTarget) this.lightboxTarget.close()
  }
}
