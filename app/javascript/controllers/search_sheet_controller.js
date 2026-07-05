import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet", "overlay"]

  open() {
    this.sheetTarget.classList.remove("translate-y-full")
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.sheetTarget.classList.add("translate-y-full")
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }
}
