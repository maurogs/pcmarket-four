import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "placeholder"]

  connect() {
    this.objectUrl = null
  }

  preview() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file || !file.type.startsWith("image/")) return

    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = URL.createObjectURL(file)

    if (this.hasPreviewTarget) {
      this.previewTarget.src = this.objectUrl
      this.previewTarget.classList.remove("hidden")
    }
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("hidden")
  }

  disconnect() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }
}
