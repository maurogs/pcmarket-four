import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bar" ]

  connect() {
    this.scroll = this.update.bind(this)
    window.addEventListener("scroll", this.scroll, { passive: true })
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.scroll)
  }

  update() {
    const scrolled = window.scrollY > 8
    this.barTarget.classList.toggle("shadow-[var(--shadow-card)]", scrolled)
    this.barTarget.classList.toggle("bg-white/95", scrolled)
    this.barTarget.classList.toggle("dark:bg-zinc-950/95", scrolled)
  }
}
