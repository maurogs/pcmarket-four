import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "overlay" ]

  connect() {
    this.previousFocus = null
    this.boundKeydown = this.keydown.bind(this)
  }

  open() {
    this.previousFocus = document.activeElement
    this.overlayTarget.hidden = false
    this.panelTarget.hidden = false
    requestAnimationFrame(() => {
      this.panelTarget.classList.remove("-translate-x-full")
      this.overlayTarget.classList.remove("opacity-0")
    })
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.boundKeydown)
    this.focusable()[0]?.focus()
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("opacity-0")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.boundKeydown)
    setTimeout(() => {
      this.panelTarget.hidden = true
      this.overlayTarget.hidden = true
    }, 200)
    this.previousFocus?.focus()
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.close()
      return
    }
    if (event.key !== "Tab") return

    const focusable = this.focusable()
    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  focusable() {
    return Array.from(
      this.panelTarget.querySelectorAll(
        'a[href], button:not([disabled]), input:not([disabled]), select, textarea, [tabindex]:not([tabindex="-1"])'
      )
    ).filter((element) => element.offsetParent !== null)
  }
}
