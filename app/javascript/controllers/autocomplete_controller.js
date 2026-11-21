import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "panel" ]
  static values = { url: String, delay: { type: Number, default: 200 } }

  connect() {
    this.timer = null
    this.selected = -1
    this.controller = null
    this.closeOnOutside = this.outside.bind(this)
    document.addEventListener("click", this.closeOnOutside)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.controller?.abort()
    document.removeEventListener("click", this.closeOnOutside)
  }

  focus() {
    if (this.inputTarget.value.trim().length >= 2) this.search()
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.fetch(), this.delayValue)
  }

  async fetch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.hide()
      return
    }

    this.controller?.abort()
    this.controller = new AbortController()

    try {
      const response = await window.fetch(
        `${this.urlValue}?q=${encodeURIComponent(query)}`,
        { headers: { Accept: "text/html" }, signal: this.controller.signal }
      )
      if (!response.ok) return

      const html = await response.text()
      const document = new DOMParser().parseFromString(html, "text/html")
      const frame = document.getElementById("search-suggestions")
      if (!frame) return

      this.panelTarget.innerHTML = frame.outerHTML
      this.selected = -1
      this.inputTarget.setAttribute("aria-expanded", "true")
      this.panelTarget.hidden = frame.querySelector("a") === null
    } catch (error) {
      if (error.name !== "AbortError") this.hide()
    }
  }

  navigate(event) {
    const options = this.options
    if (event.key === "Escape") {
      this.hide()
      return
    }
    if (options.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selected = (this.selected + 1) % options.length
      this.highlight()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selected = this.selected <= 0 ? options.length - 1 : this.selected - 1
      this.highlight()
    } else if (event.key === "Enter" && this.selected >= 0) {
      event.preventDefault()
      options[this.selected]?.click()
    }
  }

  highlight() {
    this.options.forEach((option, index) => {
      const active = index === this.selected
      option.classList.toggle("bg-slate-100", active)
      option.classList.toggle("dark:bg-zinc-800", active)
      option.setAttribute("aria-selected", active.toString())
    })
    this.options[this.selected]?.scrollIntoView({ block: "nearest" })
  }

  outside(event) {
    if (!this.element.contains(event.target)) this.hide()
  }

  hide() {
    this.panelTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.selected = -1
  }

  get options() {
    return Array.from(this.panelTarget.querySelectorAll("a"))
  }
}
