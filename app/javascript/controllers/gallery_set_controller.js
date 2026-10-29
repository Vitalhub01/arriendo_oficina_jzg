import { Controller } from "@hotwired/stimulus"

const FRAME_ID = "gallery_main_photo"

export default class extends Controller {
  static values = {
    prevUrl: String,
    nextUrl: String
  }

  handleKey(event) {
    if (event.target.matches("input, textarea, select")) return
    if (!this.element.isConnected) return

    if (event.key === "ArrowLeft" && this.prevUrlValue) {
      event.preventDefault()
      window.Turbo.visit(this.prevUrlValue, { frame: FRAME_ID, action: "advance" })
    }

    if (event.key === "ArrowRight" && this.nextUrlValue) {
      event.preventDefault()
      window.Turbo.visit(this.nextUrlValue, { frame: FRAME_ID, action: "advance" })
    }
  }
}
