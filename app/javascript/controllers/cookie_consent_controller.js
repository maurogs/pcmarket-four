import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "banner", "dialog", "analytics", "marketing" ]
  static values = { cookieName: { type: String, default: "cookie_consent" } }

  connect() {
    const stored = this.read()
    if (stored) {
      this.syncInputs(stored)
      this.bannerTarget.hidden = true
    } else {
      this.bannerTarget.hidden = false
    }
  }

  acceptAll() {
    this.save({ necessary: true, analytics: true, marketing: true })
  }

  rejectAll() {
    this.save({ necessary: true, analytics: false, marketing: false })
  }

  open() {
    this.syncInputs(this.read() || { necessary: true, analytics: false, marketing: false })
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  savePreferences() {
    this.save({
      necessary: true,
      analytics: this.analyticsTarget.checked,
      marketing: this.marketingTarget.checked
    })
  }

  save(preferences) {
    const payload = { ...preferences, version: 1, saved_at: new Date().toISOString() }
    const value = encodeURIComponent(JSON.stringify(payload))
    document.cookie = `${this.cookieNameValue}=${value};path=/;max-age=15552000;SameSite=Lax`
    this.bannerTarget.hidden = true
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  syncInputs(preferences) {
    this.analyticsTarget.checked = Boolean(preferences.analytics)
    this.marketingTarget.checked = Boolean(preferences.marketing)
  }

  read() {
    const match = document.cookie.match(
      new RegExp(`(?:^|; )${this.cookieNameValue}=([^;]*)`)
    )
    if (!match) return null

    try {
      return JSON.parse(decodeURIComponent(match[1]))
    } catch (error) {
      return null
    }
  }
}
