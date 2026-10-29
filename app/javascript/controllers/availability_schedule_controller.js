import { Controller } from "@hotwired/stimulus"
import { renderAvailabilityWeek } from "lib/availability_schedule_renderer"

const MAX_STORED_WEEKS = 20

export default class extends Controller {
  static targets = ["content", "loading", "viewToggle"]

  static values = {
    weeks: { type: Array, default: [] },
    initialWeekStart: String,
    interactive: { type: Boolean, default: false },
    loginPrompt: { type: Boolean, default: false },
    availabilityUrl: String,
    spaceId: Number
  }

  connect() {
    this.ensureMergedWeeks()
    this.mergeWeeks(this.weeksValue)
    this.view = this.hasContentTarget ? this.contentTarget.dataset.view || "hora" : "hora"
    this.syncViewToggleStyles()
    this.renderCurrentWeek()
    this.hideLoading()
    this.hasRenderedOnConnect = true
  }

  disconnect() {
    if (this.fetchAbortController) this.fetchAbortController.abort()
  }

  weeksValueChanged() {
    this.ensureMergedWeeks()
    this.mergeWeeks(this.weeksValue)

    if (!this.hasRenderedOnConnect) return

    this.renderCurrentWeek()
    this.hideLoading()
  }

  setView(event) {
    const view = event.currentTarget.dataset.view
    if (!view || view === this.view) return

    this.view = view
    this.syncViewToggleStyles()
    this.renderCurrentWeek()
  }

  navigate(event) {
    event.preventDefault()

    const link = event.currentTarget
    const weekStart = this.normalizeWeekStart(link.dataset.weekStart)
    if (!weekStart || !this.hasContentTarget) return

    this.contentTarget.dataset.weekStart = weekStart

    if (this.weekFor(weekStart)) {
      this.renderCurrentWeek()
      this.hideLoading()
      return
    }

    this.fetchSchedule(weekStart)
  }

  async fetchSchedule(weekStart) {
    if (!this.hasAvailabilityUrlValue) return

    if (this.fetchAbortController) this.fetchAbortController.abort()
    this.fetchAbortController = new AbortController()
    this.pendingWeekStart = weekStart

    this.showLoading()

    try {
      const url = new URL(this.availabilityUrlValue, window.location.origin)
      url.searchParams.set("week_start", weekStart)

      const response = await fetch(url, {
        signal: this.fetchAbortController.signal,
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) throw new Error(`availability fetch failed: ${response.status}`)

      const payload = await response.json()
      this.mergeWeeks(payload.weeks || [])
      this.persistWeeks(this.mergedWeeks)

      if (this.normalizeWeekStart(this.pendingWeekStart) === weekStart) {
        this.renderCurrentWeek()
      }
    } catch (error) {
      if (error.name === "AbortError") return

      this.renderFetchError()
    } finally {
      this.pendingWeekStart = null
      this.hideLoading()
    }
  }

  renderCurrentWeek() {
    if (!this.hasContentTarget) return

    const weekStart = this.normalizeWeekStart(
      this.contentTarget.dataset.weekStart || this.initialWeekStartValue
    )
    const week = this.weekFor(weekStart)

    if (!week) {
      if (!this.pendingWeekStart) this.fetchSchedule(weekStart)
      return
    }

    this.contentTarget.innerHTML = renderAvailabilityWeek(week, this.view, {
      interactive: this.interactiveValue,
      loginPrompt: this.loginPromptValue,
      availabilityUrl: this.availabilityUrlValue
    })
    this.contentTarget.dataset.weekStart = weekStart
    this.contentTarget.dataset.view = this.view
  }

  renderFetchError() {
    if (!this.hasContentTarget) return

    this.contentTarget.innerHTML =
      '<p class="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900">No pudimos cargar los horarios. Intenta avanzar o retroceder una semana de nuevo.</p>'
  }

  ensureMergedWeeks() {
    if (!Array.isArray(this.mergedWeeks)) {
      this.mergedWeeks = this.loadStoredWeeks()
    }
  }

  mergeWeeks(incomingWeeks) {
    if (!Array.isArray(incomingWeeks) || incomingWeeks.length === 0) return

    this.ensureMergedWeeks()

    const merged = new Map(this.mergedWeeks.map((week) => [this.normalizeWeekStart(week.weekStart), week]))
    incomingWeeks.forEach((week) => {
      merged.set(this.normalizeWeekStart(week.weekStart), week)
    })

    this.mergedWeeks = this.trimWeeks(Array.from(merged.values()).sort((left, right) =>
      left.weekStart.localeCompare(right.weekStart)
    ))
  }

  trimWeeks(weeks) {
    if (weeks.length <= MAX_STORED_WEEKS) return weeks

    const anchor = this.normalizeWeekStart(
      this.contentTarget?.dataset?.weekStart || this.initialWeekStartValue
    )
    const anchorIndex = weeks.findIndex((week) => this.normalizeWeekStart(week.weekStart) === anchor)
    const center = anchorIndex >= 0 ? anchorIndex : Math.floor(weeks.length / 2)
    const start = Math.max(0, center - Math.floor(MAX_STORED_WEEKS / 2))
    return weeks.slice(start, start + MAX_STORED_WEEKS)
  }

  weekFor(weekStart) {
    this.ensureMergedWeeks()
    const normalized = this.normalizeWeekStart(weekStart)
    return this.mergedWeeks.find((week) => this.normalizeWeekStart(week.weekStart) === normalized)
  }

  normalizeWeekStart(value) {
    if (!value) return value
    return value.slice(0, 10)
  }

  storageKey() {
    return `space-${this.spaceIdValue}-availability-weeks`
  }

  loadStoredWeeks() {
    if (!this.hasSpaceIdValue) return []

    try {
      const raw = sessionStorage.getItem(this.storageKey())
      return raw ? JSON.parse(raw) : []
    } catch {
      return []
    }
  }

  persistWeeks(weeks) {
    if (!this.hasSpaceIdValue) return

    try {
      sessionStorage.setItem(this.storageKey(), JSON.stringify(weeks))
    } catch {
      // sessionStorage full or unavailable — keep in-memory merge only
    }
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

  showLoading() {
    this.element.classList.add(...this.loadingClassNames)
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
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
