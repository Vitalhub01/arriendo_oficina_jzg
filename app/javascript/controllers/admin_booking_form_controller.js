import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scheduleFrame"]

  static values = {
    scheduleUrl: String
  }

  spaceChanged(event) {
    const spaceId = event.target.value
    if (!this.hasScheduleFrameTarget) return

    if (!spaceId) {
      this.scheduleFrameTarget.removeAttribute("src")
      this.scheduleFrameTarget.innerHTML =
        '<p class="text-sm text-gray-500">Selecciona un espacio para ver el calendario de horarios disponibles.</p>'
      return
    }

    const url = new URL(this.scheduleUrlValue, window.location.origin)
    url.searchParams.set("space_id", spaceId)
    this.scheduleFrameTarget.src = url.toString()
  }
}
