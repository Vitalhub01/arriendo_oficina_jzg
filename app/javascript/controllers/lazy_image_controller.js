import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "skeleton"]
  static values = { src: String }

  connect() {
    if (this.hasSrcValue) {
      this.observe()
      return
    }

    if (this.hasImageTarget) {
      if (this.imageTarget.complete && this.imageTarget.naturalWidth > 0) {
        this.reveal()
      } else {
        this.imageTarget.addEventListener("load", () => this.reveal())
        this.imageTarget.addEventListener("error", () => this.reveal())
      }
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  observe() {
    this.observer = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return

        const img = this.imageTarget
        img.src = this.srcValue
        img.addEventListener("load", () => this.reveal())
        img.addEventListener("error", () => this.reveal())
        this.observer.disconnect()
      },
      { rootMargin: "120px" }
    )
    this.observer.observe(this.element)
  }

  reveal() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.classList.add("opacity-0", "pointer-events-none")
    }
    if (this.hasImageTarget) {
      this.imageTarget.classList.remove("opacity-0")
    }
  }
}
