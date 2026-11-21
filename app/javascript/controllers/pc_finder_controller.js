import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "step", "progressBar", "progressLabel", "counter", "back", "next", "submit" ]
  static values = { storageKey: String }

  connect() {
    this.current = 0
    this.restore()
    this.show()
  }

  next() {
    if (this.current >= this.steps.length - 1) return
    this.current += 1
    this.show()
  }

  back() {
    if (this.current <= 0) return
    this.current -= 1
    this.show()
  }

  limitGames(event) {
    const checked = this.element.querySelectorAll("[data-pc-finder-game]:checked")
    if (checked.length <= 3) return

    event.target.checked = false
    this.flashLimit()
  }

  flashLimit() {
    const label = this.element.querySelector("[data-pc-finder-limit]")
    if (!label) return

    label.classList.remove("hidden")
    window.setTimeout(() => label.classList.add("hidden"), 2500)
  }

  show() {
    this.steps.forEach((step, index) => {
      step.classList.toggle("hidden", index !== this.current)
    })

    const total = this.steps.length
    const percent = Math.round(((this.current + 1) / total) * 100)
    if (this.hasProgressBarTarget) this.progressBarTarget.style.width = `${percent}%`
    if (this.hasProgressLabelTarget) this.progressLabelTarget.textContent = `${percent}%`
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = this.counterTarget.dataset.template
        .replace("%{current}", this.current + 1)
        .replace("%{total}", total)
    }
    if (this.hasBackTarget) this.backTarget.classList.toggle("invisible", this.current === 0)
    if (this.hasNextTarget) this.nextTarget.classList.toggle("hidden", this.current === total - 1)
    if (this.hasSubmitTarget) this.submitTarget.classList.toggle("hidden", this.current !== total - 1)

    this.persist()
  }

  persist() {
    if (!this.hasStorageKeyValue) return

    const data = {}
    this.element.querySelectorAll("input").forEach((input) => {
      if (!input.name || input.type === "submit") return
      if (input.type === "checkbox") {
        if (!data[input.name]) data[input.name] = []
        if (input.checked) data[input.name].push(input.value)
      } else if (input.type === "radio") {
        if (input.checked) data[input.name] = input.value
      } else {
        data[input.name] = input.value
      }
    })
    try {
      window.sessionStorage.setItem(this.storageKeyValue, JSON.stringify(data))
    } catch (error) {}
  }

  restore() {
    if (!this.hasStorageKeyValue) return

    let data
    try {
      data = JSON.parse(window.sessionStorage.getItem(this.storageKeyValue) || "null")
    } catch (error) {
      return
    }
    if (!data) return

    Object.entries(data).forEach(([name, value]) => {
      const inputs = this.element.querySelectorAll(`[name="${CSS.escape(name)}"]`)
      inputs.forEach((input) => {
        if (input.type === "checkbox") {
          input.checked = Array.isArray(value) && value.includes(input.value)
        } else if (input.type === "radio") {
          input.checked = value === input.value
        }
      })
    })
  }

  get steps() {
    return this.stepTargets
  }
}
