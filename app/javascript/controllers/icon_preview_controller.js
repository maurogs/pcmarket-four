import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "preview"]

  connect() {
    this.render()
  }

  render() {
    if (!this.hasSelectTarget || !this.hasPreviewTarget) return

    const name = this.selectTarget.value
    const template = this.previewTarget.dataset.template
    this.previewTarget.innerHTML = ""
    if (!name || !template) return

    const image = document.createElement("img")
    image.src = template.replace("__ICON__", name)
    image.alt = ""
    image.className = "size-5"
    this.previewTarget.appendChild(image)
  }
}
