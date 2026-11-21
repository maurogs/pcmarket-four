import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { title: String, text: String, url: String }

  async share() {
    const payload = {
      title: this.titleValue,
      text: this.textValue,
      url: this.urlValue || window.location.href
    }

    if (navigator.share) {
      try {
        await navigator.share(payload)
        return
      } catch (error) {
        if (error.name === "AbortError") return
      }
    }

    try {
      await navigator.clipboard.writeText(payload.url)
      this.flashCopied()
    } catch (error) {
      window.prompt(this.element.dataset.copyPrompt, payload.url)
    }
  }

  flashCopied() {
    const label = this.element.querySelector("[data-share-label]")
    if (!label) return

    const original = label.textContent
    label.textContent = label.dataset.copiedLabel
    setTimeout(() => { label.textContent = original }, 2000)
  }
}
