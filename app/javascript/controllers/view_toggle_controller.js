import { Controller } from "@hotwired/stimulus"

const COOKIE = "listing_view"
const GRID_CLASSES = [ "grid-cols-2", "md:grid-cols-3", "xl:grid-cols-4" ]

export default class extends Controller {
  static targets = [ "container", "gridButton", "listButton" ]

  connect() {
    this.view = this.readCookie() || "grid"
    this.apply()
  }

  grid() {
    this.persist("grid")
  }

  list() {
    this.persist("list")
  }

  persist(view) {
    this.view = view
    document.cookie = `${COOKIE}=${view};path=/;max-age=31536000;samesite=lax`
    this.apply()
  }

  apply() {
    if (!this.hasContainerTarget) return

    const container = this.containerTarget
    if (this.view === "list") {
      GRID_CLASSES.forEach((name) => container.classList.remove(name))
      container.classList.add("grid-cols-1")
    } else {
      container.classList.remove("grid-cols-1")
      GRID_CLASSES.forEach((name) => container.classList.add(name))
    }

    this.toggleActive(this.hasGridButtonTarget ? this.gridButtonTarget : null, this.view === "grid")
    this.toggleActive(this.hasListButtonTarget ? this.listButtonTarget : null, this.view === "list")
  }

  toggleActive(button, active) {
    if (!button) return

    button.classList.toggle("bg-slate-100", active)
    button.classList.toggle("text-brand-700", active)
    button.classList.toggle("dark:bg-zinc-800", active)
  }

  readCookie() {
    const match = document.cookie.match(/(?:^|; )listing_view=(grid|list)/)
    return match && match[1]
  }
}
