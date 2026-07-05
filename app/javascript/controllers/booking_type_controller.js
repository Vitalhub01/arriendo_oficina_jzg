import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  show(event) {
    this.panelTargets.forEach(p => p.classList.add("hidden"))
    const panel = this.panelTargets.find(p => p.dataset.bookingType === event.params.type)
    if (panel) panel.classList.remove("hidden")
  }
}
