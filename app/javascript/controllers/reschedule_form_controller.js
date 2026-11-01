import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date", "startTime", "slotCount", "slotRate", "reservationMode", "selectionSummary"]

  static values = {
    mode: String
  }

  connect() {
    this.updateSummary()
    this.syncAvailabilityScheduleView(this.modeValue)
  }

  selectSlot(event) {
    const { date, startTime } = event.currentTarget.dataset
    if (!date || !startTime) return

    this.setFieldValues({ date, startTime })
    this.updateSummary()
  }

  selectBloque(event) {
    const { date, slotRateId } = event.currentTarget.dataset
    if (!date || !slotRateId) return

    this.setFieldValues({ date, slotRateId })
    this.updateSummary()
  }

  selectJornada(event) {
    const { date } = event.currentTarget.dataset
    if (!date) return

    this.setFieldValues({ date })
    this.updateSummary()
  }

  fieldChanged() {
    this.updateSummary()
  }

  setReservationModeFromSchedule(_mode) {
    // Vista fijada al tipo de reserva original; no cambia el modo al usar toggles.
  }

  setFieldValues({ date, startTime, slotRateId }) {
    if (date) {
      this.dateTargets.forEach((field) => {
        field.value = date
      })
    }
    if (startTime && this.hasStartTimeTarget) {
      this.startTimeTargets.forEach((field) => {
        field.value = startTime
      })
    }
    if (slotRateId && this.hasSlotRateTarget) {
      this.slotRateTargets.forEach((field) => {
        field.value = slotRateId
      })
    }
  }

  updateSummary() {
    if (!this.hasSelectionSummaryTarget) return

    const dateValue = this.dateTargets[0]?.value
    if (!dateValue) {
      this.selectionSummaryTargets.forEach((el) => {
        el.textContent = "Elige un horario en el calendario."
      })
      return
    }

    const formattedDate = this.formatDateLabel(dateValue)
    let text = formattedDate

    if (this.modeValue === "hora" && this.hasStartTimeTarget) {
      const start = this.startTimeTargets[0]?.value
      const slots = this.slotCountTargets[0]?.value
      if (start) text += ` · inicio ${start}`
      if (slots) text += ` · ${slots} hora(s)`
    } else if (this.modeValue === "bloque" && this.hasSlotRateTarget) {
      const select = this.slotRateTargets[0]
      const label = select?.selectedOptions?.[0]?.textContent?.trim()
      if (label) text += ` · ${label}`
    } else if (this.modeValue === "jornada") {
      text += " · jornada completa"
    }

    this.selectionSummaryTargets.forEach((el) => {
      el.textContent = `Nuevo horario: ${text}`
    })
  }

  formatDateLabel(iso) {
    const [year, month, day] = iso.split("-").map(Number)
    const date = new Date(year, month - 1, day)
    return new Intl.DateTimeFormat("es-CL", { weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(date)
  }

  syncAvailabilityScheduleView(mode) {
    const scheduleEl = this.element.querySelector('[data-controller~="availability-schedule"]')
    if (!scheduleEl) return

    const schedule = this.application.getControllerForElementAndIdentifier(scheduleEl, "availability-schedule")
    schedule?.setViewFromBookingForm(mode)
  }
}
