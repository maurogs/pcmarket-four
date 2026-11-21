import { Controller } from "@hotwired/stimulus"

const COLLAPSED_KEY = "pcmarket-admin-sidebar"

export default class extends Controller {
  static targets = [ "panel", "label", "title", "overlay", "collapseIcon" ]

  connect() {
    this.collapsed = this.readCollapsed()
    this.applyCollapsed()
  }

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden", "lg:overflow-auto")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden", "lg:overflow-auto")
  }

  toggleCollapsed() {
    this.collapsed = !this.collapsed
    this.persist()
    this.applyCollapsed()
  }

  applyCollapsed() {
    this.panelTarget.classList.toggle("lg:w-[4.75rem]", this.collapsed)
    this.panelTarget.classList.toggle("lg:w-64", !this.collapsed)
    this.labelTargets.forEach((label) => label.classList.toggle("lg:hidden", this.collapsed))
    this.titleTargets.forEach((title) => title.classList.toggle("lg:hidden", this.collapsed))
    if (this.hasCollapseIconTarget) {
      this.collapseIconTarget.classList.toggle("rotate-180", this.collapsed)
    }
  }

  readCollapsed() {
    try {
      return localStorage.getItem(COLLAPSED_KEY) === "true"
    } catch (error) {
      return false
    }
  }

  persist() {
    try {
      localStorage.setItem(COLLAPSED_KEY, this.collapsed.toString())
    } catch (error) {
      // Private browsing may reject storage; the current session still works.
    }
  }
}
