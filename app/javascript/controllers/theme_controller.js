import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggle" ]

  connect() {
    this.updateLabels()
  }

  toggle() {
    const next = document.documentElement.classList.contains("dark") ? "light" : "dark"
    this.apply(next)
    this.persist(next)
  }

  apply(theme) {
    document.documentElement.classList.toggle("dark", theme === "dark")
    this.updateLabels()
  }

  persist(theme) {
    try {
      localStorage.setItem("pcmarket-theme", theme)
    } catch (error) {
      // Storage can be unavailable in private browsing; the cookie is enough.
    }
    document.cookie = `theme=${theme};path=/;max-age=31536000;SameSite=Lax`
  }

  updateLabels() {
    const isDark = document.documentElement.classList.contains("dark")
    this.toggleTargets.forEach((button) => {
      const label = isDark ? button.dataset.labelLight : button.dataset.labelDark
      if (label) button.setAttribute("aria-label", label)
      button.setAttribute("aria-pressed", isDark.toString())
    })
  }
}
