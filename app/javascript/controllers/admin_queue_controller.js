import { Controller } from "@hotwired/stimulus"

// Keyboard shortcuts for the moderation queue: j/k move between cards, a
// approves the focused card and r focuses its rejection reason.
export default class extends Controller {
  static targets = [ "card", "approveForm", "rejectForm", "rejectReason" ]

  connect() {
    this.activeIndex = 0
    this.boundKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
    this.highlight()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  onKeydown(event) {
    if (this.isTyping(event.target)) return
    if (!this.hasCardTarget) return

    switch (event.key) {
      case "j":
        event.preventDefault()
        this.move(1)
        break
      case "k":
        event.preventDefault()
        this.move(-1)
        break
      case "a":
        event.preventDefault()
        this.activeApproveForm()?.requestSubmit()
        break
      case "r":
        event.preventDefault()
        this.activeRejectReason()?.focus()
        break
    }
  }

  move(delta) {
    const next = Math.min(Math.max(this.activeIndex + delta, 0), this.cardTargets.length - 1)
    this.activeIndex = next
    this.highlight()
    this.cardTargets[next].scrollIntoView({ behavior: "smooth", block: "center" })
  }

  highlight() {
    this.cardTargets.forEach((card, index) => {
      card.classList.toggle("ring-2", index === this.activeIndex)
      card.classList.toggle("ring-brand-500", index === this.activeIndex)
    })
  }

  activeApproveForm() {
    const card = this.cardTargets[this.activeIndex]
    return card?.querySelector("[data-admin-queue-target='approveForm']")
  }

  activeRejectReason() {
    const card = this.cardTargets[this.activeIndex]
    return card?.querySelector("[data-admin-queue-target='rejectReason']")
  }

  isTyping(target) {
    const tag = target?.tagName?.toLowerCase()
    return tag === "input" || tag === "textarea" || tag === "select" || target?.isContentEditable
  }
}
