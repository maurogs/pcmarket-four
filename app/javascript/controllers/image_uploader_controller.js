import { Controller } from "@hotwired/stimulus"

// Photos section of the sell form (see seller/listings/_form.html.erb).
//
// - Newly picked files get preview tiles (object URLs, revoked on disconnect)
//   and direct-upload progress bars driven by ActiveStorage's
//   direct-upload:initialize/progress/error/end events on the file input.
// - Tiles reorder by dragging the grip handle or with the arrow buttons; the
//   hidden listing[image_order] field (JSON of attachment ids) and the Cover
//   badge on the first tile stay in sync. New files have no attachment id
//   yet, so they never enter image_order — the server appends them.
// - The counter and the over-limit warning count kept tiles (remove checkbox
//   unchecked) plus pending new files against the max value.
const TILE_SELECTOR = "[data-image-uploader-target~='tile']"

export default class extends Controller {
  static targets = ["input", "grid", "order", "counter", "warning", "template", "tile",
                    "preview", "progress", "bar"]
  static values = { max: Number }

  connect() {
    this.objectUrls = new Set()
    this.pendingFiles = []
    this.filesByTile = new WeakMap()
    this.uploads = new Map()
    this.draggedTile = null
    this.refresh()
  }

  disconnect() {
    this.objectUrls.forEach((url) => URL.revokeObjectURL(url))
    this.objectUrls.clear()
  }

  // --- New files -------------------------------------------------------------

  filesSelected() {
    for (const file of Array.from(this.inputTarget.files || [])) {
      const tile = this.templateTarget.content.firstElementChild.cloneNode(true)
      const url = URL.createObjectURL(file)
      this.objectUrls.add(url)
      this.previewTargetFor(tile).src = url
      this.filesByTile.set(tile, file)
      this.pendingFiles.push(file)
      this.gridTarget.appendChild(tile)
    }
    this.rebuildInput()
    this.refresh()
  }

  removeNew(event) {
    const tile = event.target.closest(TILE_SELECTOR)
    const file = this.filesByTile.get(tile)
    this.pendingFiles = this.pendingFiles.filter((pending) => pending !== file)
    const url = this.previewTargetFor(tile).src
    if (this.objectUrls.has(url)) {
      this.objectUrls.delete(url)
      URL.revokeObjectURL(url)
    }
    tile.remove()
    this.rebuildInput()
    this.refresh()
  }

  // The browser replaces input.files on every pick, so keep our own list and
  // hand ActiveStorage the full set on submit.
  rebuildInput() {
    const transfer = new DataTransfer()
    this.pendingFiles.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
  }

  // --- Direct upload progress --------------------------------------------------

  uploadInitialize(event) {
    const { id, file } = event.detail
    const tile = this.tileForFile(file)
    this.uploads.set(id, tile)
    if (!tile) return

    const progress = this.progressTargetFor(tile)
    progress.classList.remove("opacity-0")
    this.barTargetFor(tile).style.width = "0%"
  }

  uploadProgress(event) {
    const tile = this.uploads.get(event.detail.id)
    if (tile) this.barTargetFor(tile).style.width = `${event.detail.progress}%`
  }

  uploadError(event) {
    const tile = this.uploads.get(event.detail.id)
    if (!tile) return

    this.barTargetFor(tile).classList.replace("bg-primary-500", "bg-red-500")
    tile.classList.add("border-red-500")
  }

  uploadEnd(event) {
    const tile = this.uploads.get(event.detail.id)
    if (!tile) return

    this.barTargetFor(tile).style.width = "100%"
    this.progressTargetFor(tile).classList.add("opacity-0")
  }

  // --- Reordering --------------------------------------------------------------

  moveLeft(event) {
    this.move(event.target.closest(TILE_SELECTOR), -1)
  }

  moveRight(event) {
    this.move(event.target.closest(TILE_SELECTOR), 1)
  }

  move(tile, direction) {
    if (!tile) return

    const sibling = direction < 0 ? tile.previousElementSibling : tile.nextElementSibling
    if (!sibling) return

    if (direction < 0) {
      this.gridTarget.insertBefore(tile, sibling)
    } else {
      this.gridTarget.insertBefore(sibling, tile)
    }
    this.syncOrder()
  }

  dragStart(event) {
    this.draggedTile = event.target.closest(TILE_SELECTOR)
    if (this.draggedTile) this.draggedTile.classList.add("opacity-40")
  }

  dragOver(event) {
    if (!this.draggedTile) return

    event.preventDefault()
    const over = event.target.closest(TILE_SELECTOR)
    if (!over || over === this.draggedTile || over.parentElement !== this.gridTarget) return

    const rect = over.getBoundingClientRect()
    const after = event.clientX - rect.left > rect.width / 2
    this.gridTarget.insertBefore(this.draggedTile, after ? over.nextElementSibling : over)
    this.syncOrder()
  }

  dragEnd() {
    if (this.draggedTile) this.draggedTile.classList.remove("opacity-40")
    this.draggedTile = null
    this.syncOrder()
  }

  // --- Counter, Cover badge and hidden order field -----------------------------

  toggleRemove() {
    this.refresh()
  }

  refresh() {
    const kept = this.activeTiles.length
    this.counterTarget.textContent = `${kept} / ${this.maxValue}`
    this.warningTarget.classList.toggle("hidden", kept <= this.maxValue)
    this.counterTarget.classList.toggle("text-red-600", kept > this.maxValue)
    this.syncOrder()
  }

  syncOrder() {
    const tiles = this.tileTargets
    const ids = tiles
      .filter((tile) => !this.isRemoved(tile))
      .map((tile) => tile.dataset.imageUploaderId)
      .filter((id) => id !== "")
    this.orderTarget.value = JSON.stringify(ids)

    tiles.forEach((tile, index) => {
      tile.querySelector("[data-image-uploader-target~='badge']").classList.toggle("hidden", index !== 0)
    })
  }

  // --- Helpers -------------------------------------------------------------------

  get activeTiles() {
    return this.tileTargets.filter((tile) => !this.isRemoved(tile))
  }

  isRemoved(tile) {
    const checkbox = tile.querySelector("input[type=checkbox]")
    return checkbox !== null && checkbox.checked
  }

  tileForFile(file) {
    return this.tileTargets.find((tile) => this.filesByTile.get(tile) === file)
  }

  previewTargetFor(tile) {
    return tile.querySelector("[data-image-uploader-target~='preview']")
  }

  progressTargetFor(tile) {
    return tile.querySelector("[data-image-uploader-target~='progress']")
  }

  barTargetFor(tile) {
    return tile.querySelector("[data-image-uploader-target~='bar']")
  }
}
