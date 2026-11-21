import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.form = this.element.querySelector("form")
    this.original = this.icon ? this.icon.getAttribute("class") : null
    this.onSubmitEnd = this.onSubmitEnd.bind(this)
    this.form?.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    this.form?.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  toggle() {
    if (!this.icon) return

    this.icon.classList.toggle("fill-current")
    this.icon.classList.toggle("text-rose-600")
    this.icon.classList.toggle("dark:text-rose-400")
  }

  onSubmitEnd(event) {
    if (event.detail.success || !this.icon) return

    if (this.original === null) {
      this.icon.removeAttribute("class")
    } else {
      this.icon.setAttribute("class", this.original)
    }
  }

  get icon() {
    return this.element.querySelector("svg")
  }
}
