import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["main", "thumb"]
  static values = {
    prevUrl: String,
    nextUrl: String
  }

  handleKey(event) {
    if (event.target.matches("input, textarea, select")) return

    if (event.key === "ArrowLeft" && this.prevUrlValue) {
      event.preventDefault()
      window.Turbo.visit(this.prevUrlValue, { action: "replace" })
    }

    if (event.key === "ArrowRight" && this.nextUrlValue) {
      event.preventDefault()
      window.Turbo.visit(this.nextUrlValue, { action: "replace" })
    }
  }
}
