import { Controller } from "@hotwired/stimulus"

// Checkout accordion: "Continue" opens the next section and scrolls it into
// view. Every section stays inside the same form, so it works without JS too.
export default class extends Controller {
  static targets = ["step"]

  next(event) {
    const current = event.currentTarget.closest("details")
    const index = this.stepTargets.indexOf(current)
    const step = this.stepTargets[index + 1]
    if (!step) return

    step.open = true
    step.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
