import { Controller } from "@hotwired/stimulus"

// Mobile navigation drawer: open/close with focus handling and scroll lock.
export default class extends Controller {
  static classes = ["open"]
  static targets = ["panel"]

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    this.unlock()
  }

  open(event) {
    event.preventDefault()
    this.element.classList.add("open")
    this.panelTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.onKeydown)
    this.panelTarget.querySelector("a, button")?.focus()
  }

  close() {
    this.element.classList.remove("open")
    this.panelTarget.classList.add("hidden")
    this.unlock()
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  unlock() {
    document.body.style.overflow = ""
  }
}
