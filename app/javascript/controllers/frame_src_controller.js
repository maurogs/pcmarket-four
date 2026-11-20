import { Controller } from "@hotwired/stimulus"

// Points the sell form's `listing_specs` Turbo Frame at the spec-fields
// endpoint whenever the seller picks another category (Phase 3 step 2).
// The frame is server-rendered on first load, so this only reacts to
// changes; clearing the select empties the frame without a request.
export default class extends Controller {
  static targets = ["select", "frame"]
  static values = { url: String, listingId: String }

  refresh() {
    const categoryId = this.selectTarget.value
    if (!categoryId) {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.innerHTML = ""
      return
    }

    const params = new URLSearchParams({ category_id: categoryId })
    if (this.listingIdValue) params.set("listing_id", this.listingIdValue)
    this.frameTarget.src = `${this.urlValue}?${params}`
  }
}
