import { Controller } from "@hotwired/stimulus"

// Minimal HTML editor toolbar: wraps the current selection with inline tags,
// inserts block tags at the caret and mirrors the textarea into a preview tab.
export default class extends Controller {
  static targets = ["textarea", "preview", "editPanel", "previewPanel", "tab"]

  connect() {
    this.updatePreview()
  }

  wrap(event) {
    const tag = event.currentTarget.dataset.tag
    if (!tag || !this.hasTextareaTarget) return

    const textarea = this.textareaTarget
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const selected = textarea.value.slice(start, end)
    if (tag === "a") {
      const url = window.prompt(this.element.dataset.linkPrompt || "https://")
      if (!url) return
      this.replaceSelection(`<a href="${url}">${selected || url}</a>`)
      return
    }
    if (["ul"].includes(tag)) {
      const items = (selected || this.element.dataset.listItem || "Item")
        .split("\n").filter(Boolean).map((line) => `  <li>${line}</li>`).join("\n")
      this.replaceSelection(`<ul>\n${items}\n</ul>`)
      return
    }
    this.replaceSelection(`<${tag}>${selected}</${tag}>`)
  }

  replaceSelection(text) {
    const textarea = this.textareaTarget
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    textarea.setRangeText(text, start, end, "end")
    textarea.focus()
    this.updatePreview()
  }

  updatePreview() {
    if (!this.hasPreviewTarget || !this.hasTextareaTarget) return
    this.previewTarget.innerHTML = this.textareaTarget.value
  }

  showEdit(event) {
    event.preventDefault()
    this.editPanelTarget.hidden = false
    this.previewPanelTarget.hidden = true
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", tab.dataset.panel === "edit"))
  }

  showPreview(event) {
    event.preventDefault()
    this.updatePreview()
    this.editPanelTarget.hidden = true
    this.previewPanelTarget.hidden = false
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", tab.dataset.panel === "preview"))
  }
}
