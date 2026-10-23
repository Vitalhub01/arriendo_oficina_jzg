import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "loading"]

  connect() {
    this.element.addEventListener("turbo:before-fetch-request", this.showLoading.bind(this))
    this.element.addEventListener("turbo:frame-load", this.hideLoading.bind(this))
    this.element.addEventListener("turbo:frame-missing", this.hideLoading.bind(this))
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
