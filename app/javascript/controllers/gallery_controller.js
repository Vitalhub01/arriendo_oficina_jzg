import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["main", "fullscreen"]

  open() {
    this.fullscreenTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.fullscreenTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  next() {
    const items = this.mainTarget.querySelectorAll("[data-gallery-index]")
    // Simple scroll for MVP
    this.mainTarget.scrollBy({ left: 300, behavior: "smooth" })
  }
}
