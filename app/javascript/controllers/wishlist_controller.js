import { Controller } from "@hotwired/stimulus"

// Placeholder wishlist heart: toggles the pressed state only. Real
// persistence arrives with the wishlist phase.
export default class extends Controller {
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const pressed = this.element.getAttribute("aria-pressed") === "true"
    this.element.setAttribute("aria-pressed", String(!pressed))
    this.element.classList.toggle("text-primary-600", !pressed)
  }
}
