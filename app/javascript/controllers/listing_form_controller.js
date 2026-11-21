import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "progressBar", "progressText", "previews", "order", "input", "dropzone", "error",
    "title", "titleCounter", "description", "descriptionCounter", "shippingFields", "preview",
    "sortable"
  ]

  static values = {
    maxImages: Number,
    maxBytes: Number,
    accept: String,
    invalidType: String,
    tooLarge: String,
    tooMany: String,
    progress: String
  }

  connect() {
    this.count()
    this.observeSections()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  count() {
    if (this.hasTitleTarget) {
      this.titleCounterTarget.textContent = `${this.titleTarget.value.length} / ${this.titleTarget.maxLength}`
    }
    if (this.hasDescriptionTarget) {
      this.descriptionCounterTarget.textContent =
        `${this.descriptionTarget.value.trim().length} / minimum 30`
    }
  }

  goTo(event) {
    event.preventDefault()
    const anchor = event.currentTarget.dataset.anchor
    const section = document.getElementById(anchor)
    if (section) section.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  categorySelected() {
    const frame = document.getElementById("listing_specs")
    if (frame) frame.setAttribute("aria-busy", "true")
  }

  filesSelected() {
    this.clearError()
    const files = Array.from(this.inputTarget.files || [])
    const accepted = this.acceptValue.split(",")
    const existing = this.hasPreviewTarget ? this.previewTargets.filter((item) => item.dataset.attachmentId).length : 0
    const room = Math.max(this.maxImagesValue - existing, 0)

    const valid = files.filter((file) => {
      if (file.size > this.maxBytesValue) {
        this.showError(this.tooLargeValue)
        return false
      }
      if (!accepted.includes(file.type)) {
        this.showError(this.invalidTypeValue)
        return false
      }
      return true
    })

    if (valid.length > room) {
      this.showError(this.tooManyValue)
      this.inputTarget.value = ""
      this.renderPreviews([])
      return
    }

    this.renderPreviews(valid)
  }

  renderPreviews(files) {
    if (!this.hasPreviewsTarget) return
    this.previewsTarget.innerHTML = ""
    files.forEach((file) => {
      const item = document.createElement("li")
      item.className = "overflow-hidden rounded-lg border border-slate-200 dark:border-zinc-700"
      const image = document.createElement("img")
      image.src = URL.createObjectURL(file)
      image.alt = file.name
      image.className = "aspect-[4/3] w-full object-cover"
      image.addEventListener("load", () => URL.revokeObjectURL(image.src), { once: true })
      item.appendChild(image)
      this.previewsTarget.appendChild(item)
    })
  }

  dragover(event) {
    event.preventDefault()
    event.currentTarget.classList.add("border-brand-500")
  }

  dragstart(event) {
    this.dragSource = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.attachmentId || "")
  }

  dragend() {
    this.dragSource = null
    this.dropzoneTargets.forEach((zone) => zone.classList.remove("border-brand-500"))
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTargets.forEach((zone) => zone.classList.remove("border-brand-500"))
    const source = this.dragSource
    if (!source || !source.dataset.attachmentId) return

    const target = event.target.closest("[data-attachment-id]")
    if (target && target !== source) {
      const box = target.getBoundingClientRect()
      const after = event.clientX > box.left + box.width / 2
      target.parentElement.insertBefore(source, after ? target.nextSibling : target)
    } else if (this.hasSortableTarget) {
      this.sortableTarget.appendChild(source)
    }
    this.syncOrder()
  }

  syncOrder() {
    if (!this.hasOrderTarget) return
    const ids = this.previewTargets
      .map((item) => item.dataset.attachmentId)
      .filter((id) => id)
    this.orderTarget.value = ids.join(",")
  }

  toggleRemoval(event) {
    const preview = event.currentTarget.closest("[data-attachment-id]")
    if (preview) preview.classList.toggle("opacity-40", event.currentTarget.checked)
  }

  shippingToggled(event) {
    if (!this.hasShippingFieldsTarget) return
    this.shippingFieldsTarget.classList.toggle("opacity-50", !event.currentTarget.checked)
  }

  freeShippingToggled(event) {
    if (event.currentTarget.checked) return
    this.count()
  }

  tagToggled(event) {
    const label = event.currentTarget.closest("label")
    if (!label) return
    label.classList.toggle("border-brand-600", event.currentTarget.checked)
    label.classList.toggle("bg-brand-700", event.currentTarget.checked)
    label.classList.toggle("text-white", event.currentTarget.checked)
  }

  observeSections() {
    const sections = Array.from(this.element.querySelectorAll("section[id^='section-']"))
    if (!sections.length || !window.IntersectionObserver) return

    this.observer = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0]
      if (!visible) return

      const index = sections.indexOf(visible.target)
      if (index < 0) return

      if (this.hasProgressBarTarget) {
        this.progressBarTarget.style.width = `${((index + 1) / sections.length) * 100}%`
      }
      if (this.hasProgressTextTarget) {
        this.progressTextTarget.textContent = this.progressValue.replace("%{step}", index + 1)
      }
    }, { rootMargin: "-30% 0px -50% 0px", threshold: [0.1, 0.5] })

    sections.forEach((section) => this.observer.observe(section))
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}
