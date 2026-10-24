import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "loading"]

  connect() {
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

  navigate(event) {
    const link = event.currentTarget
    const weekStart = link.dataset.weekStart
    if (!weekStart) return

    const cached = this.element.querySelector(`template[data-week-start="${weekStart}"]`)
    if (!cached || !this.hasContentTarget) return

    event.preventDefault()
    this.contentTarget.innerHTML = cached.innerHTML
    this.hideLoading()
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
