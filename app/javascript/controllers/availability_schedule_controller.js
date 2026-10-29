import { Controller } from "@hotwired/stimulus"
import { renderAvailabilityWeek } from "lib/availability_schedule_renderer"

export default class extends Controller {
  static targets = ["content", "loading", "viewToggle"]

  static values = {
    weeks: { type: Array, default: [] },
    initialWeekStart: String,
    interactive: { type: Boolean, default: false },
    loginPrompt: { type: Boolean, default: false },
    availabilityUrl: String
  }

  connect() {
    this.view = this.hasContentTarget ? this.contentTarget.dataset.view || "hora" : "hora"
    this.syncViewToggleStyles()
    this.renderCurrentWeek()

    this.onBeforeFetchRequest = (event) => this.showLoading(event)
    this.onHideLoading = () => this.hideLoading()

    this.element.addEventListener("turbo:before-fetch-request", this.onBeforeFetchRequest)
    this.element.addEventListener("turbo:frame-load", this.onHideLoading)
    this.element.addEventListener("turbo:frame-missing", this.onHideLoading)
    this.element.addEventListener("turbo:fetch-request-error", this.onHideLoading)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-fetch-request", this.onBeforeFetchRequest)
    this.element.removeEventListener("turbo:frame-load", this.onHideLoading)
    this.element.removeEventListener("turbo:frame-missing", this.onHideLoading)
    this.element.removeEventListener("turbo:fetch-request-error", this.onHideLoading)
  }

  setView(event) {
    const view = event.currentTarget.dataset.view
    if (!view || view === this.view) return

    this.view = view
    this.syncViewToggleStyles()
    this.renderCurrentWeek()
  }

  navigate(event) {
    const link = event.currentTarget
    const weekStart = link.dataset.weekStart
    if (!weekStart || !this.hasContentTarget) return

    if (!this.weekFor(weekStart)) return

    event.preventDefault()
    this.contentTarget.dataset.weekStart = weekStart
    this.renderCurrentWeek()
    this.hideLoading()
  }

  renderCurrentWeek() {
    if (!this.hasContentTarget) return

    const weekStart = this.contentTarget.dataset.weekStart || this.initialWeekStartValue
    const week = this.weekFor(weekStart)
    if (!week) return

    this.contentTarget.innerHTML = renderAvailabilityWeek(week, this.view, {
      interactive: this.interactiveValue,
      loginPrompt: this.loginPromptValue,
      availabilityUrl: this.availabilityUrlValue
    })
    this.contentTarget.dataset.weekStart = weekStart
    this.contentTarget.dataset.view = this.view
  }

  weekFor(weekStart) {
    return this.weeksValue.find((week) => week.weekStart === weekStart)
  }

  syncViewToggleStyles() {
    if (!this.hasViewToggleTarget) return

    this.viewToggleTargets.forEach((button) => {
      const active = button.dataset.view === this.view
      button.setAttribute("aria-pressed", active ? "true" : "false")
      button.classList.toggle("border-gray-900", active)
      button.classList.toggle("bg-gray-900", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("border-gray-200", !active)
      button.classList.toggle("text-gray-700", !active)
    })
  }

  showLoading(event) {
    if (event && this.isPrefetchRequest(event)) return

    this.element.classList.add(...this.loadingClassNames)
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
  }

  isPrefetchRequest(event) {
    const headers = event.detail?.fetchOptions?.headers
    if (!headers) return false

    if (typeof headers.get === "function") {
      return headers.get("X-Sec-Purpose") === "prefetch"
    }

    return headers["X-Sec-Purpose"] === "prefetch"
  }

  hideLoading() {
    this.element.classList.remove(...this.loadingClassNames)
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
  }

  get loadingClassNames() {
    const value = this.element.dataset.availabilityScheduleLoadingClass
    return value ? value.split(/\s+/).filter(Boolean) : ["opacity-50", "pointer-events-none"]
  }
}
