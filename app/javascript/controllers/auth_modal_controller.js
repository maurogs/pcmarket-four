import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onFrameLoad = this.onFrameLoad.bind(this)
    this.onBackdrop = this.onBackdrop.bind(this)
    document.addEventListener("turbo:frame-load", this.onFrameLoad)
    this.element.addEventListener("click", this.onBackdrop)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.onFrameLoad)
    this.element.removeEventListener("click", this.onBackdrop)
  }

  onFrameLoad(event) {
    if (event.target.id !== "auth-modal") return
    if (!this.element.open) this.element.showModal()
  }

  onBackdrop(event) {
    if (event.target === this.element) this.close()
  }

  close() {
    this.element.close()
    const frame = this.element.querySelector("turbo-frame")
    if (frame) frame.innerHTML = ""
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }
}
