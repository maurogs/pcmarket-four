import { Controller } from "@hotwired/stimulus"

// Drag-and-drop and keyboard reordering for sibling lists. Every item carries
// data-sortable-id; the ordered ids are PATCHed to the configured endpoint.
export default class extends Controller {
  static targets = ["list"]
  static values = { url: String, parent: String }

  connect() {
    this.dragged = null
  }

  dragStart(event) {
    const item = event.target.closest("[data-sortable-id]")
    if (!item || item.dataset.sortableParent !== this.parentValue) return

    this.dragged = item
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", item.dataset.sortableId)
  }

  dragOver(event) {
    const item = event.target.closest("[data-sortable-id]")
    if (!item || !this.dragged || item === this.dragged) return
    if (item.dataset.sortableParent !== this.parentValue) return

    event.preventDefault()
    const rect = item.getBoundingClientRect()
    const after = event.clientY > rect.top + rect.height / 2
    item.parentElement.insertBefore(this.dragged, after ? item.nextSibling : item)
  }

  dragEnd() {
    if (!this.dragged) return

    this.dragged = null
    this.persist()
  }

  moveUp(event) {
    const item = event.currentTarget.closest("[data-sortable-id]")
    if (!item || !item.previousElementSibling) return

    item.parentElement.insertBefore(item, item.previousElementSibling)
    this.persist()
  }

  moveDown(event) {
    const item = event.currentTarget.closest("[data-sortable-id]")
    if (!item || !item.nextElementSibling) return

    item.parentElement.insertBefore(item.nextElementSibling, item)
    this.persist()
  }

  persist() {
    const list = this.element.querySelector("[data-sortable-list]")
    if (!list) return

    const ids = Array.from(list.querySelectorAll("[data-sortable-id]"))
                     .filter((item) => item.dataset.sortableParent === this.parentValue)
                     .map((item) => item.dataset.sortableId)
    const body = new URLSearchParams()
    body.append("ordered_ids[]", ids.join(","))
    body.append("parent_id", this.parentValue)
    body.append("filter_definition_id", this.element.dataset.filterDefinitionId || "")

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "text/vnd.turbo-stream.html"
      },
      body
    })
  }
}
