import { Controller } from "@hotwired/stimulus"

// PC Finder quiz: shows one fieldset at a time inside the GET form. Without
// JS every step stays visible and the form submits normally; with JS only the
// current step is shown, the progress dots track it, and Next waits until the
// step has a selection (the games step allows at most 3 checkboxes). The
// `step` value is the 1-based step number from the URL (?step=N, used by the
// results summary chips), so it maps to a zero-based index; it defaults to 0.
const MAX_GAMES = 3

export default class extends Controller {
  static targets = [ "step", "dot", "next", "back", "submit" ]
  static values = { step: { type: Number, default: 0 } }

  connect() {
    this.current = this.startIndex()
    this.keyHandlers = this.stepTargets.map((step) => {
      const handler = (event) => this.onKeydown(event)
      step.addEventListener("keydown", handler)
      return { step, handler }
    })
    this.changeHandler = (event) => this.onChange(event)
    this.element.addEventListener("change", this.changeHandler)
    this.render()
  }

  disconnect() {
    this.keyHandlers?.forEach(({ step, handler }) => step.removeEventListener("keydown", handler))
    this.element.removeEventListener("change", this.changeHandler)
  }

  next() {
    this.advance()
  }

  back() {
    if (this.current === 0) return
    this.current -= 1
    this.render()
    this.focusLegend()
  }

  // --- Internals --------------------------------------------------------------

  advance() {
    const last = this.stepTargets.length - 1
    if (this.current >= last || !this.hasSelection(this.stepTargets[this.current])) return false
    this.current += 1
    this.render()
    this.focusLegend()
    return true
  }

  startIndex() {
    const last = Math.max(this.stepTargets.length - 1, 0)
    const step = Number.isNaN(this.stepValue) ? 1 : this.stepValue
    return Math.min(Math.max(step - 1, 0), last)
  }

  render() {
    const last = this.stepTargets.length - 1
    this.stepTargets.forEach((step, index) => {
      step.hidden = index !== this.current
      if (index !== this.current) return
      const back = this.control(step, "back")
      if (back) back.hidden = this.current === 0
      const next = this.control(step, "next")
      if (next) {
        next.hidden = this.current === last
        next.disabled = !this.hasSelection(step)
      }
      const submit = this.control(step, "submit")
      if (submit) submit.hidden = this.current !== last
    })
    this.dotTargets.forEach((dot, index) => {
      dot.classList.remove("bg-cream-300", "dark:bg-cream-surface", "bg-primary-300", "bg-primary-600")
      if (index === this.current) {
        dot.classList.add("bg-primary-600")
        dot.setAttribute("aria-current", "step")
      } else {
        if (index < this.current) dot.classList.add("bg-primary-300")
        else dot.classList.add("bg-cream-300", "dark:bg-cream-surface")
        dot.removeAttribute("aria-current")
      }
    })
  }

  onChange(event) {
    const step = this.stepTargets[this.current]
    if (!step || !step.contains(event.target)) return
    this.enforceMaxGames(step)
    const next = this.control(step, "next")
    if (next) next.disabled = !this.hasSelection(step)
    this.focusLegend()
  }

  onKeydown(event) {
    if (event.key !== "Enter" || event.target.closest("button")) return
    if (this.advance()) event.preventDefault()
  }

  control(step, name) {
    return step.querySelector(`[data-quiz-target~="${name}"]`)
  }

  hasSelection(step) {
    return step.querySelectorAll("input:checked").length > 0
  }

  enforceMaxGames(step) {
    const boxes = [ ...step.querySelectorAll('input[type="checkbox"]') ]
    if (boxes.length === 0) return
    const full = boxes.filter((box) => box.checked).length >= MAX_GAMES
    boxes.forEach((box) => { box.disabled = full && !box.checked })
  }

  focusLegend() {
    this.stepTargets[this.current]?.querySelector("legend")?.focus()
  }
}

const MAX_GAMES = 3
