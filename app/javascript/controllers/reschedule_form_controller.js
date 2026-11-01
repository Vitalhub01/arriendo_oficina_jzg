import { Controller } from "@hotwired/stimulus"
import {
  formatCLP,
  hourlySelectionValid,
  periodIssueMessage,
  periodWindowIssue,
  selectableHourlyBlocks
} from "lib/reservation_pricing"

export default class extends Controller {
  static targets = [
    "date",
    "startTime",
    "slotCount",
    "slotRate",
    "reservationMode",
    "selectionSummary",
    "bloqueWarning",
    "horaWarning",
    "submit"
  ]

  static values = {
    mode: String,
    minimumSlots: Number,
    slotCount: Number,
    blocksByDay: Object,
    overrides: Array,
    reservedIntervals: Array,
    today: String,
    nowTime: String,
    slotRates: Array
  }

  connect() {
    this.syncCalendarWeek()
    this.refreshModeFields()
    this.updateSummary()
    this.syncAvailabilityScheduleView(this.modeValue)
  }

  selectSlot(event) {
    const { date, startTime } = event.currentTarget.dataset
    if (!date || !startTime) return

    this.setFieldValues({ date, startTime })
    this.syncCalendarWeek()
    this.updateSummary()
  }

  selectBloque(event) {
    const { date, slotRateId } = event.currentTarget.dataset
    if (!date || !slotRateId) return

    this.setFieldValues({ date, slotRateId })
    this.syncCalendarWeek()
    this.updateSummary()
  }

  selectJornada(event) {
    const { date } = event.currentTarget.dataset
    if (!date) return

    this.setFieldValues({ date })
    this.syncCalendarWeek()
    this.updateSummary()
  }

  dateChanged() {
    this.syncCalendarWeek()
    this.refreshModeFields()
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
    if (this.modeValue === "hora") {
      this.refreshStarts()
    } else if (this.modeValue === "bloque") {
      this.refreshBloqueRates()
    }
    if (startTime && this.hasStartTimeTarget) {
      this.startTimeTargets.forEach((field) => {
        field.value = startTime
      })
      this.validateHoraSelection()
    }
    if (slotRateId && this.hasSlotRateTarget) {
      this.slotRateTargets.forEach((field) => {
        field.value = slotRateId
      })
      this.validateBloqueSelection()
    }
  }

  refreshModeFields() {
    if (this.modeValue === "hora") {
      this.refreshStarts()
      this.validateHoraSelection()
    } else if (this.modeValue === "bloque") {
      this.refreshBloqueRates()
      this.validateBloqueSelection()
    } else {
      this.setSubmitDisabled(false)
    }
  }

  refreshStarts() {
    if (this.modeValue !== "hora" || !this.hasStartTimeTarget || !this.hasDateTarget) return

    const dateIso = this.dateTargets[0]?.value
    if (!dateIso) return

    const slotCount = this.effectiveSlotCount()
    const blocks = selectableHourlyBlocks(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      this.todayValue,
      this.nowTimeValue
    ).filter((block) =>
      hourlySelectionValid(
        this.blocksByDayValue,
        this.overridesValue,
        this.reservedIntervalsValue,
        dateIso,
        slotCount,
        block.start,
        this.minimumSlotsValue,
        this.todayValue,
        this.nowTimeValue
      )
    )

    this.startTimeTargets.forEach((select) => {
      const previous = select.value
      select.innerHTML = ""

      const blank = document.createElement("option")
      blank.value = ""
      blank.textContent = "Elige una franja en el calendario"
      select.appendChild(blank)

      blocks.forEach((block) => {
        const option = document.createElement("option")
        const price = this.priceForBlock(block, dateIso)
        option.value = block.start
        option.textContent = `${block.start} – ${block.end} (${formatCLP(price)})`
        select.appendChild(option)
      })

      if (blocks.length === 0) {
        blank.textContent = "Sin franjas disponibles para esta fecha"
      } else if (previous && blocks.some((b) => b.start === previous)) {
        select.value = previous
      }
    })
  }

  refreshBloqueRates() {
    if (this.modeValue !== "bloque" || !this.hasSlotRateTarget || !this.hasDateTarget) return

    const dateIso = this.dateTargets[0]?.value
    if (!dateIso) return

    const previous = this.slotRateTargets[0]?.value
    const availableRates = (this.slotRatesValue || []).filter((rate) => {
      const issue = periodWindowIssue(
        this.blocksByDayValue,
        this.overridesValue,
        this.reservedIntervalsValue,
        dateIso,
        rate.start,
        rate.end,
        this.todayValue,
        this.nowTimeValue
      )
      return !issue
    })

    this.slotRateTargets.forEach((select) => {
      select.innerHTML = ""

      const rates = availableRates.length > 0 ? availableRates : this.slotRatesValue || []
      rates.forEach((rate) => {
        const option = document.createElement("option")
        option.value = String(rate.id)
        option.textContent = `${rate.name} (${rate.start} – ${rate.end})`
        select.appendChild(option)
      })

      if (previous && rates.some((r) => String(r.id) === previous)) {
        select.value = previous
      } else if (rates[0]) {
        select.value = String(rates[0].id)
      }
    })
  }

  validateHoraSelection() {
    if (!this.hasHoraWarningTarget) return true

    const dateIso = this.dateTargets[0]?.value
    const startTime = this.startTimeTargets[0]?.value
    const slotCount = this.effectiveSlotCount()

    if (!dateIso || !startTime) {
      this.showHoraWarning(null)
      this.setSubmitDisabled(true)
      return false
    }

    const valid = hourlySelectionValid(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      slotCount,
      startTime,
      this.minimumSlotsValue,
      this.todayValue,
      this.nowTimeValue
    )

    if (!valid) {
      this.showHoraWarning("unavailable")
      this.setSubmitDisabled(true)
      return false
    }

    this.showHoraWarning(null)
    this.setSubmitDisabled(false)
    return true
  }

  validateBloqueSelection() {
    if (!this.hasBloqueWarningTarget) return true

    const dateIso = this.dateTargets[0]?.value
    const rate = this.selectedSlotRate()
    if (!dateIso || !rate) {
      this.showBloqueWarning("no_schedule")
      this.setSubmitDisabled(true)
      return false
    }

    const issue = periodWindowIssue(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      rate.start,
      rate.end,
      this.todayValue,
      this.nowTimeValue
    )

    if (issue) {
      this.showBloqueWarning(issue)
      this.setSubmitDisabled(true)
      return false
    }

    this.showBloqueWarning(null)
    this.setSubmitDisabled(false)
    return true
  }

  selectedSlotRate() {
    if (!this.hasSlotRateTarget) return null
    const id = parseInt(this.slotRateTargets[0]?.value, 10)
    return this.slotRatesValue.find((r) => r.id === id) || null
  }

  effectiveSlotCount() {
    if (this.hasSlotCountTarget) {
      const fromField = parseInt(this.slotCountTargets[0]?.value, 10)
      if (fromField > 0) return fromField
    }
    return this.slotCountValue || this.minimumSlotsValue
  }

  priceForBlock(block, dateIso) {
    const override = this.overridesValue.find(
      (o) => o.schedule_block_id === block.id && o.date === dateIso
    )
    if (override?.price) return override.price
    return block.price
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
    let complete = false

    if (this.modeValue === "hora" && this.hasStartTimeTarget) {
      const start = this.startTimeTargets[0]?.value
      const slots = this.effectiveSlotCount()
      if (start) {
        text += ` · inicio ${start}`
        if (slots) text += ` · ${slots} hora(s)`
        complete = true
      } else {
        text += " · elige una franja en el calendario"
      }
      this.validateHoraSelection()
    } else if (this.modeValue === "bloque" && this.hasSlotRateTarget) {
      const select = this.slotRateTargets[0]
      const label = select?.selectedOptions?.[0]?.textContent?.trim()
      if (label) {
        text += ` · ${label}`
        complete = true
      }
      this.validateBloqueSelection()
    } else if (this.modeValue === "jornada") {
      text += " · jornada completa"
      complete = true
      this.setSubmitDisabled(false)
    }

    const prefix = complete ? "Nuevo horario: " : ""
    this.selectionSummaryTargets.forEach((el) => {
      el.textContent = `${prefix}${text}`
    })
  }

  formatDateLabel(iso) {
    const [year, month, day] = iso.split("-").map(Number)
    const date = new Date(year, month - 1, day)
    return new Intl.DateTimeFormat("es-CL", { weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(date)
  }

  syncCalendarWeek() {
    const dateIso = this.dateTargets[0]?.value
    if (!dateIso) return

    const scheduleEl = this.element.querySelector('[data-controller~="availability-schedule"]')
    if (!scheduleEl) return

    const schedule = this.application.getControllerForElementAndIdentifier(scheduleEl, "availability-schedule")
    schedule?.showWeekContaining(dateIso)
  }

  syncAvailabilityScheduleView(mode) {
    const scheduleEl = this.element.querySelector('[data-controller~="availability-schedule"]')
    if (!scheduleEl) return

    const schedule = this.application.getControllerForElementAndIdentifier(scheduleEl, "availability-schedule")
    schedule?.setViewFromBookingForm(mode)
  }

  showHoraWarning(issue) {
    if (!this.hasHoraWarningTarget) return

    this.horaWarningTargets.forEach((el) => {
      if (!issue) {
        el.textContent = ""
        el.classList.add("hidden")
        return
      }
      el.textContent = periodIssueMessage(issue)
      el.classList.remove("hidden")
    })
  }

  showBloqueWarning(issue) {
    if (!this.hasBloqueWarningTarget) return

    this.bloqueWarningTargets.forEach((el) => {
      if (!issue) {
        el.textContent = ""
        el.classList.add("hidden")
        return
      }
      el.textContent = periodIssueMessage(issue)
      el.classList.remove("hidden")
    })
  }

  setSubmitDisabled(disabled) {
    if (!this.hasSubmitTarget) return
    this.submitTargets.forEach((el) => {
      el.disabled = disabled
      el.setAttribute("aria-disabled", disabled ? "true" : "false")
    })
  }
}
