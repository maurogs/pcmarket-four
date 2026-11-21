import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "skeleton" ]

  connect() {
    this.timeout = null
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  submit(event) {
    const form = event.target.form
    if (!form) return
    if (event.target.matches("input[type='search'], input[type='text'], input[type='number']")) return

    form.requestSubmit()
  }

  debouncedSubmit(event) {
    const form = event.target.form
    if (!form) return

    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => form.requestSubmit(), 400)
  }

  loading() {
    if (this.hasSkeletonTarget) this.skeletonTarget.classList.remove("hidden")
  }

  loaded() {
    if (this.hasSkeletonTarget) this.skeletonTarget.classList.add("hidden")
  }
}
