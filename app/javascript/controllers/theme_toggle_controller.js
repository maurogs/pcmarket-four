import { Controller } from "@hotwired/stimulus"

// Class-strategy dark mode. Initial state is applied by an inline script in
// the layout head (no flash on load); this controller toggles and persists.
export default class extends Controller {
  toggle() {
    const dark = document.documentElement.classList.toggle("dark")
    try {
      localStorage.setItem("theme", dark ? "dark" : "light")
    } catch {
      // Private mode: keep the toggle working for this page only.
    }
  }
}
