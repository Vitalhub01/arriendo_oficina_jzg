import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "slotCount",
    "total",
    "startTime",
    "durationLabel",
    "date",
    "reservationMode",
    "horaFields",
    "bloqueFields",
    "jornadaFields",
    "slotRate",
    "bloqueTotal",
    "bloqueDurationLabel",
    "jornadaTotal",
    "jornadaDurationLabel",
    "bloqueWarning",
    "jornadaWarning",
    "submit",
    "modeSummary"
  ]
  static values = {
    minimumSlots: Number,
    blocksByDay: Object,
    overrides: Array,
    reservedIntervals: Array,
    today: String,
    nowTime: String,
    slotRates: Array,
    jornada: Object
  }

  connect() {
    this.periodBlockedMessage =
      "Hay al menos una hora reservada o bloqueada en esa fecha; no se puede reservar el bloque o la jornada completa."
    this.modeSummaries = {
      hora: "Elige la fecha, la hora de inicio y cuántas horas seguidas necesitas.",
      bloque: "Reservas la mañana (08:00–14:00) o la tarde (14:00–20:00) completa en el día elegido.",
      jornada: "Reservas el día completo en el horario de jornada configurado para este espacio."
    }
    this.applyModeUI(this.currentMode())
    this.refreshStarts()
    this.updateTotal()
  }

  openPanel() {
    const panel = document.getElementById("space-booking-panel")
    if (!panel) return
    panel.classList.remove("hidden")
    panel.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  closePanel() {
    document.getElementById("space-booking-panel")?.classList.add("hidden")
  }

  dateChanged() {
    this.refreshStarts()
    this.updateTotal()
  }

  selectSlot(event) {
    const { date, startTime } = event.currentTarget.dataset
    if (!date || !startTime) return

    this.applyReservationMode("hora")

    this.dateTargets.forEach((field) => {
      field.value = date
    })
    this.refreshStarts()
    this.startTimeTargets.forEach((select) => {
      select.value = startTime
    })
    this.updateTotal()

    if (window.matchMedia("(max-width: 1023px)").matches) {
      this.openPanel()
    }
  }

  selectBloque(event) {
    const { date, slotRateId } = event.currentTarget.dataset
    if (!date || !slotRateId) return

    this.applyReservationMode("bloque")

    this.dateTargets.forEach((field) => {
      field.value = date
    })
    this.slotRateTargets.forEach((field) => {
      field.value = slotRateId
    })
    this.updateTotal()

    if (window.matchMedia("(max-width: 1023px)").matches) {
      this.openPanel()
    }
  }

  selectJornada(event) {
    const { date } = event.currentTarget.dataset
    if (!date) return

    this.applyReservationMode("jornada")

    this.dateTargets.forEach((field) => {
      field.value = date
    })
    this.updateTotal()

    if (window.matchMedia("(max-width: 1023px)").matches) {
      this.openPanel()
    }
  }

  applyReservationMode(mode) {
    if (!this.hasReservationModeTarget) return

    this.reservationModeTargets.forEach((field) => {
      field.value = mode
    })
    this.applyModeUI(mode)
  }

  modeChanged(event) {
    const mode = this.modeFromEvent(event)
    this.reservationModeTargets.forEach((el) => {
      el.value = mode
    })
    this.applyModeUI(mode)
    this.updateTotal()
  }

  startTimeChanged(event) {
    const value = event?.target?.value
    if (value) {
      this.startTimeTargets.forEach((el) => {
        el.value = value
      })
    }
    this.updateTotal()
  }

  slotRateChanged(event) {
    const value = event?.target?.value
    if (value) {
      this.slotRateTargets.forEach((el) => {
        el.value = value
      })
    }
    this.updateTotal()
  }

  slotCountChanged(event) {
    const value = event?.target?.value
    if (value !== undefined && value !== "") {
      this.slotCountTargets.forEach((el) => {
        el.value = value
      })
    }
    this.updateTotal()
  }

  modeFromEvent(event) {
    if (event?.target?.dataset?.bookingFormTarget === "reservationMode") {
      return event.target.value
    }
    return this.currentMode()
  }

  applyModeUI(mode) {
    this.toggleSection(this.horaFieldsTargets, mode === "hora")
    this.toggleSection(this.bloqueFieldsTargets, mode === "bloque")
    this.toggleSection(this.jornadaFieldsTargets, mode === "jornada")

    const hora = mode === "hora"
    const bloque = mode === "bloque"

    this.startTimeTargets.forEach((el) => {
      el.required = hora
      el.disabled = !hora
    })
    this.slotCountTargets.forEach((el) => {
      el.required = hora
      el.disabled = !hora
    })
    this.slotRateTargets.forEach((el) => {
      el.required = bloque
      el.disabled = !bloque
    })

    if (this.hasModeSummaryTarget) {
      const text = this.modeSummaries[mode] || ""
      this.modeSummaryTargets.forEach((el) => {
        el.textContent = text
      })
    }

    if (hora) {
      this.hidePeriodWarning(this.bloqueWarningTargets)
      this.hidePeriodWarning(this.jornadaWarningTargets)
      this.refreshStarts()
    } else if (mode === "bloque") {
      this.hidePeriodWarning(this.jornadaWarningTargets)
    } else if (mode === "jornada") {
      this.hidePeriodWarning(this.bloqueWarningTargets)
    }
  }

  toggleSection(targets, visible) {
    targets.forEach((el) => {
      el.classList.toggle("hidden", !visible)
    })
  }

  currentMode() {
    return this.reservationModeTargets[0]?.value || "hora"
  }

  refreshStarts() {
    if (!this.hasStartTimeTarget || !this.hasDateTarget) return
    if (this.currentMode() !== "hora") return

    const dateValue = this.dateTargets[0]?.value
    if (!dateValue) return

    const date = new Date(dateValue + "T12:00:00")
    const day = (date.getDay() + 6) % 7
    const blocks = this.blocksByDayValue[String(day)] || []
    const dateIso = dateValue
    const selectableBlocks = blocks.filter(
      (block) =>
        this.isActiveOnDate(block, dateIso) &&
        !this.isBlockedOnDate(block, dateIso) &&
        !this.isPastBlock(block, dateIso) &&
        !this.isReservedBlock(block, dateIso)
    )

    this.startTimeTargets.forEach((select) => {
      const previous = select.value
      select.innerHTML = ""

      selectableBlocks.forEach((block) => {
        const option = document.createElement("option")
        const price = this.priceForBlock(block, dateIso)
        option.value = block.start
        option.textContent = `${block.start} – ${block.end} (${this.formatCLP(price)})`
        select.appendChild(option)
      })

      if (selectableBlocks.length === 0) {
        const option = document.createElement("option")
        option.value = ""
        option.textContent = "Sin franjas disponibles"
        select.appendChild(option)
      } else if (previous && selectableBlocks.some((b) => b.start === previous)) {
        select.value = previous
      }
    })
  }

  updateTotal() {
    const mode = this.currentMode()

    if (mode === "bloque") {
      this.updateBloqueTotal()
      return
    }
    if (mode === "jornada") {
      this.updateJornadaTotal()
      return
    }

    this.hidePeriodWarning(this.bloqueWarningTargets)
    this.hidePeriodWarning(this.jornadaWarningTargets)

    const slotCount = parseInt(this.slotCountTargets[0]?.value || this.minimumSlotsValue, 10)
    const startTime = this.hasStartTimeTarget ? this.startTimeTargets[0]?.value : ""
    const total = this.calculateTotal(slotCount, startTime)
    const durationMinutes = this.totalDurationMinutes(slotCount, startTime)

    this.totalTargets.forEach((el) => {
      el.textContent = this.formatCLP(total)
    })

    this.updateDurationLabel(this.durationLabelTargets, durationMinutes)
    this.setSubmitDisabled(slotCount < this.minimumSlotsValue || !startTime)
  }

  updateBloqueTotal() {
    const rate = this.selectedSlotRate()
    const dateIso = this.hasDateTarget ? this.dateTargets[0]?.value : ""
    const windowIssue = rate && dateIso ? this.periodWindowIssue(dateIso, rate.start, rate.end) : "no_schedule"

    if (windowIssue) {
      this.showPeriodWarning(this.bloqueWarningTargets, windowIssue)
      this.bloqueTotalTargets.forEach((el) => {
        el.textContent = "—"
      })
      this.bloqueDurationLabelTargets.forEach((el) => {
        el.textContent = ""
      })
      this.setSubmitDisabled(true)
      return
    }

    this.hidePeriodWarning(this.bloqueWarningTargets)
    const durationMinutes = rate ? this.minutesBetween(rate.start, rate.end) : 0
    const total = rate?.block_price || 0

    this.bloqueTotalTargets.forEach((el) => {
      el.textContent = this.formatCLP(total)
    })
    this.updateDurationLabel(this.bloqueDurationLabelTargets, durationMinutes, rate?.name)
    this.setSubmitDisabled(false)
  }

  updateJornadaTotal() {
    const jornada = this.jornadaValue
    const dateIso = this.hasDateTarget ? this.dateTargets[0]?.value : ""
    const windowIssue =
      jornada?.start && jornada?.end && dateIso
        ? this.periodWindowIssue(dateIso, jornada.start, jornada.end)
        : "no_schedule"

    if (windowIssue) {
      this.showPeriodWarning(this.jornadaWarningTargets, windowIssue)
      this.jornadaTotalTargets.forEach((el) => {
        el.textContent = "—"
      })
      this.jornadaDurationLabelTargets.forEach((el) => {
        el.textContent = ""
      })
      this.setSubmitDisabled(true)
      return
    }

    this.hidePeriodWarning(this.jornadaWarningTargets)
    const durationMinutes = jornada?.start && jornada?.end
      ? this.minutesBetween(jornada.start, jornada.end)
      : 0
    const total = jornada?.price || 0

    this.jornadaTotalTargets.forEach((el) => {
      el.textContent = this.formatCLP(total)
    })
    this.updateDurationLabel(this.jornadaDurationLabelTargets, durationMinutes, "Jornada completa")
    this.setSubmitDisabled(false)
  }

  selectedSlotRate() {
    if (!this.hasSlotRateTarget) return null
    const id = parseInt(this.slotRateTargets[0]?.value, 10)
    return this.slotRatesValue.find((r) => r.id === id) || this.slotRatesValue[0]
  }

  updateDurationLabel(targets, durationMinutes, prefix) {
    if (!targets?.length) return

    const hours = Math.floor(durationMinutes / 60)
    const minutes = durationMinutes % 60
    let label = `Duración: ${durationMinutes} min`
    if (hours > 0 && minutes > 0) {
      label = `Duración: ${hours}h ${minutes}min`
    } else if (hours > 0) {
      label = `Duración: ${hours} hora(s)`
    }
    if (prefix) {
      label = `${prefix} · ${label}`
    }
    targets.forEach((el) => {
      el.textContent = label
    })
  }

  minutesBetween(start, end) {
    const [sh, sm] = start.split(":").map(Number)
    const [eh, em] = end.split(":").map(Number)
    return (eh * 60 + em) - (sh * 60 + sm)
  }

  calculateTotal(slotCount, startTime) {
    const blocks = this.blocksForStart(startTime)
    if (blocks.length === 0) return 0

    const dateIso = this.hasDateTarget ? this.dateTargets[0]?.value : ""
    const startIndex = blocks.findIndex((b) => b.start === startTime)
    if (startIndex < 0) return 0

    let total = 0
    for (let i = 0; i < slotCount; i++) {
      const block = blocks[startIndex + i]
      if (!block) return 0
      if (!this.isActiveOnDate(block, dateIso)) return 0
      if (this.isBlockedOnDate(block, dateIso)) return 0
      if (this.isPastBlock(block, dateIso)) return 0
      if (this.isReservedBlock(block, dateIso)) return 0
      if (i > 0 && blocks[startIndex + i - 1].end !== block.start) return 0
      total += this.priceForBlock(block, dateIso)
    }
    return total
  }

  priceForBlock(block, dateIso) {
    const override = this.overridesValue.find(
      (o) => o.schedule_block_id === block.id && o.date === dateIso
    )
    if (override?.price) return override.price
    return block.price
  }

  isBlockedOnDate(block, dateIso) {
    return this.overridesValue.some(
      (o) => o.schedule_block_id === block.id && o.date === dateIso && o.blocked
    )
  }

  isReservedBlock(block, dateIso) {
    const blockStart = this.parseDateTime(dateIso, block.start)
    const blockEnd = this.parseDateTime(dateIso, block.end)
    return (this.reservedIntervalsValue || []).some((interval) => {
      const start = new Date(interval.start)
      const end = new Date(interval.end)
      return start < blockEnd && end > blockStart
    })
  }

  periodWindowIssue(dateIso, windowStart, windowEnd) {
    const blocks = this.blocksInWindow(dateIso, windowStart, windowEnd)
    if (blocks.length === 0) return "no_schedule"

    const contiguous = blocks.every((block, index) => {
      if (index === 0) return true
      return blocks[index - 1].end === block.start
    })
    if (!contiguous) return "no_schedule"

    for (const block of blocks) {
      if (!this.isActiveOnDate(block, dateIso)) return "unavailable"
      if (this.isBlockedOnDate(block, dateIso)) return "blocked"
      if (this.isPastBlock(block, dateIso)) return "past"
      if (this.isReservedBlock(block, dateIso)) return "reserved"
    }

    return null
  }

  blocksInWindow(dateIso, windowStart, windowEnd) {
    const blocks = this.blocksForDate(dateIso)
    return blocks
      .filter((block) => block.start >= windowStart && block.end <= windowEnd)
      .sort((a, b) => a.start.localeCompare(b.start))
  }

  blocksForDate(dateIso) {
    if (!dateIso) return []
    const date = new Date(dateIso + "T12:00:00")
    const day = (date.getDay() + 6) % 7
    return this.blocksByDayValue[String(day)] || []
  }

  showPeriodWarning(targets, issue) {
    const message =
      issue === "reserved" || issue === "blocked"
        ? this.periodBlockedMessage
        : "No hay horario disponible para esa fecha en la franja elegida."

    targets.forEach((el) => {
      el.textContent = message
      el.classList.remove("hidden")
    })
  }

  hidePeriodWarning(targets) {
    targets.forEach((el) => {
      el.textContent = ""
      el.classList.add("hidden")
    })
  }

  setSubmitDisabled(disabled) {
    if (!this.hasSubmitTarget) return
    this.submitTargets.forEach((el) => {
      el.disabled = disabled
    })
  }

  parseDateTime(dateIso, time) {
    const [year, month, day] = dateIso.split("-").map(Number)
    const [hour, minute] = time.split(":").map(Number)
    return new Date(year, month - 1, day, hour, minute, 0, 0)
  }

  isActiveOnDate(block, dateIso) {
    if (!block.effective_until) return true
    return dateIso <= block.effective_until
  }

  isPastBlock(block, dateIso) {
    if (this.hasTodayValue && this.hasNowTimeValue) {
      if (dateIso > this.todayValue) return false
      if (dateIso < this.todayValue) return true
      return block.start < this.nowTimeValue
    }

    const [year, month, day] = dateIso.split("-").map(Number)
    const [hour, minute] = block.start.split(":").map(Number)
    const startAt = new Date(year, month - 1, day, hour, minute, 0, 0)
    return startAt <= new Date()
  }

  totalDurationMinutes(slotCount, startTime) {
    const blocks = this.blocksForStart(startTime)
    const startIndex = blocks.findIndex((b) => b.start === startTime)
    if (startIndex < 0) return 0

    let minutes = 0
    for (let i = 0; i < slotCount; i++) {
      const block = blocks[startIndex + i]
      if (!block) return 0
      minutes += block.duration
    }
    return minutes
  }

  blocksForStart(_startTime) {
    if (!this.hasDateTarget) return []
    const dateValue = this.dateTargets[0]?.value
    if (!dateValue) return []
    const date = new Date(dateValue + "T12:00:00")
    const day = (date.getDay() + 6) % 7
    return this.blocksByDayValue[String(day)] || []
  }

  increment() {
    if (this.currentMode() !== "hora") return
    const field = this.slotCountTargets[0]
    if (!field) return
    const next = parseInt(field.value || this.minimumSlotsValue, 10) + 1
    this.slotCountTargets.forEach((el) => {
      el.value = next
    })
    this.updateTotal()
  }

  decrement() {
    if (this.currentMode() !== "hora") return
    const field = this.slotCountTargets[0]
    if (!field) return
    const current = parseInt(field.value || this.minimumSlotsValue, 10)
    if (current > this.minimumSlotsValue) {
      const next = current - 1
      this.slotCountTargets.forEach((el) => {
        el.value = next
      })
      this.updateTotal()
    }
  }

  formatCLP(cents) {
    return new Intl.NumberFormat("es-CL", {
      style: "currency",
      currency: "CLP",
      maximumFractionDigits: 0
    }).format(cents)
  }
}
