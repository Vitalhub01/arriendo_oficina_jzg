import { Controller } from "@hotwired/stimulus"
import {
  calculateHourlyTotal,
  formatCLP,
  periodIssueMessage,
  periodWindowIssue,
  selectableHourlyBlocks
} from "lib/reservation_pricing"

export default class extends Controller {
  static targets = [
    "loading",
    "form",
    "horaFields",
    "bloqueFields",
    "jornadaFields",
    "modePrice",
    "total",
    "scheduleRange",
    "quotePanel",
    "quoteError",
    "modeInput",
    "confirmDate",
    "confirmStartTime",
    "confirmSlotCount",
    "confirmReservationMode",
    "confirmSlotRateId",
    "confirmSubmit"
  ]

  static values = {
    minimumSlots: Number,
    blocksByDay: Object,
    overrides: Array,
    reservedIntervals: Array,
    today: String,
    nowTime: String,
    slotRates: Array,
    jornada: Object,
    equipmentPerHourCents: Number
  }

  connect() {
    this.onBeforeFetchRequest = (event) => this.showLoading(event)
    this.onHideLoading = () => this.hideLoading()

    this.element.addEventListener("turbo:before-fetch-request", this.onBeforeFetchRequest)
    this.element.addEventListener("turbo:frame-load", this.onHideLoading)
    this.element.addEventListener("turbo:frame-missing", this.onHideLoading)
    this.element.addEventListener("turbo:fetch-request-error", this.onHideLoading)

    this.applyModeUI(this.currentMode())
    this.refreshClientState()
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    this.element.removeEventListener("turbo:before-fetch-request", this.onBeforeFetchRequest)
    this.element.removeEventListener("turbo:frame-load", this.onHideLoading)
    this.element.removeEventListener("turbo:frame-missing", this.onHideLoading)
    this.element.removeEventListener("turbo:fetch-request-error", this.onHideLoading)
  }

  submit() {
    if (this.hasFormTarget) this.formTarget.requestSubmit()
  }

  submitDebounced() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.submit(), 350)
  }

  modeChanged(event) {
    const mode = event?.target?.value
    if (!mode) return

    this.modeInputTargets.forEach((input) => {
      if (input.value === mode) input.checked = true
    })
    this.applyModeUI(mode)
    this.refreshClientState()
  }

  dateChanged() {
    this.refreshStarts()
    this.submit()
  }

  startTimeChanged() {
    this.refreshClientState()
  }

  slotCountChanged() {
    this.refreshClientState()
  }

  slotRateChanged() {
    this.refreshClientState()
  }

  equipmentChanged() {
    this.submitDebounced()
  }

  applyModeUI(mode) {
    this.toggleSection(this.horaFieldsTargets, mode === "hora")
    this.toggleSection(this.bloqueFieldsTargets, mode === "bloque")
    this.toggleSection(this.jornadaFieldsTargets, mode === "jornada")
    this.updateModePriceLabels()
  }

  toggleSection(targets, visible) {
    targets.forEach((el) => {
      el.classList.toggle("hidden", !visible)
    })
  }

  currentMode() {
    const checked = this.modeInputTargets.find((input) => input.checked)
    if (checked) return checked.value

    const hidden = this.formField("reservation_mode")
    return hidden?.value || "hora"
  }

  formField(name) {
    if (!this.hasFormTarget) return null
    return this.formTarget.elements.namedItem(name)
  }

  dateValue() {
    const field = this.formField("date")
    return field?.value || ""
  }

  refreshStarts() {
    const mode = this.currentMode()
    if (mode !== "hora") return

    const startTimeField = this.formField("start_time")
    if (!startTimeField) return

    const dateIso = this.dateValue()
    const blocks = selectableHourlyBlocks(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      this.todayValue,
      this.nowTimeValue
    )

    const previous = startTimeField.value
    startTimeField.innerHTML = ""

    blocks.forEach((block) => {
      const option = document.createElement("option")
      option.value = block.start
      option.textContent = `${block.start} – ${block.end}`
      startTimeField.appendChild(option)
    })

    if (blocks.length === 0) {
      const option = document.createElement("option")
      option.value = ""
      option.textContent = "Sin franjas disponibles"
      startTimeField.appendChild(option)
    } else if (previous && blocks.some((b) => b.start === previous)) {
      startTimeField.value = previous
    }
  }

  refreshClientState() {
    const mode = this.currentMode()
    const dateIso = this.dateValue()

    if (mode === "hora") {
      this.refreshHourlySummary(dateIso)
    } else if (mode === "bloque") {
      this.refreshBloqueSummary(dateIso)
    } else {
      this.refreshJornadaSummary(dateIso)
    }

    this.updateModePriceLabels()
    this.syncConfirmFields()
  }

  syncConfirmFields() {
    if (!this.hasConfirmDateTarget) return

    const mode = this.currentMode()
    const dateIso = this.dateValue()
    const startTime = this.formField("start_time")?.value || ""
    const slotCount = this.formField("slot_count")?.value || ""
    const slotRateId = this.formField("slot_rate_id")?.value || ""

    this.confirmReservationModeTargets.forEach((el) => {
      el.value = mode
    })
    this.confirmDateTargets.forEach((el) => {
      el.value = dateIso
    })
    this.confirmStartTimeTargets.forEach((el) => {
      el.value = startTime
    })
    this.confirmSlotCountTargets.forEach((el) => {
      el.value = slotCount
    })
    this.confirmSlotRateIdTargets.forEach((el) => {
      el.value = slotRateId
    })
  }

  refreshHourlySummary(dateIso) {
    const slotCount = parseInt(this.formField("slot_count")?.value || this.minimumSlotsValue, 10)
    const startTime = this.formField("start_time")?.value || ""
    const valid =
      startTime &&
      slotCount >= this.minimumSlotsValue &&
      selectableHourlyBlocks(
        this.blocksByDayValue,
        this.overridesValue,
        this.reservedIntervalsValue,
        dateIso,
        this.todayValue,
        this.nowTimeValue
      ).some((b) => b.start === startTime)

    if (!valid) {
      this.showQuoteError("Ajusta fecha y horario para ver el total.")
      return
    }

    let total = calculateHourlyTotal(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      slotCount,
      startTime,
      this.todayValue,
      this.nowTimeValue
    )

    total += this.equipmentExtraCents(slotCount)
    const endTime = this.hourlyEndTime(dateIso, startTime, slotCount)
    this.showQuoteSuccess(startTime, endTime, total, `${slotCount} hora(s)`)
  }

  refreshBloqueSummary(dateIso) {
    const rate = this.selectedSlotRate()
    if (!rate) {
      this.showQuoteError("Elige mañana o tarde.")
      return
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
      this.showQuoteError(periodIssueMessage(issue))
      return
    }

    this.showQuoteSuccess(rate.start, rate.end, rate.block_price, "Bloque (mañana / tarde)")
  }

  refreshJornadaSummary(dateIso) {
    const jornada = this.jornadaValue
    if (!jornada?.start || !jornada?.end) {
      this.showQuoteError("Este espacio no tiene jornada completa configurada.")
      return
    }

    const issue = periodWindowIssue(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      jornada.start,
      jornada.end,
      this.todayValue,
      this.nowTimeValue
    )

    if (issue) {
      this.showQuoteError(periodIssueMessage(issue))
      return
    }

    this.showQuoteSuccess(jornada.start, jornada.end, jornada.price, "Jornada completa")
  }

  hourlyEndTime(dateIso, startTime, slotCount) {
    const blocks = selectableHourlyBlocks(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      this.todayValue,
      this.nowTimeValue
    )
    const startIndex = blocks.findIndex((b) => b.start === startTime)
    if (startIndex < 0) return startTime

    const lastBlock = blocks[startIndex + slotCount - 1]
    return lastBlock?.end || startTime
  }

  equipmentExtraCents(slotCount) {
    if (!this.equipmentPerHourCentsValue) return 0
    const checkboxes = this.formTarget?.querySelectorAll('input[name="rented_equipment_item_ids[]"]:checked')
    if (!checkboxes?.length) return 0
    return this.equipmentPerHourCentsValue * slotCount
  }

  selectedSlotRate() {
    const field = this.formField("slot_rate_id")
    const id = parseInt(field?.value, 10)
    return this.slotRatesValue.find((r) => r.id === id) || this.slotRatesValue[0]
  }

  showQuoteSuccess(startTime, endTime, totalCents, modeLabel) {
    this.setConfirmSubmitEnabled(true)
    if (this.hasQuoteErrorTarget) {
      this.quoteErrorTargets.forEach((el) => el.classList.add("hidden"))
    }
    if (this.hasQuotePanelTarget) {
      this.quotePanelTargets.forEach((el) => el.classList.remove("hidden"))
    }
    if (this.hasScheduleRangeTarget) {
      this.scheduleRangeTargets.forEach((el) => {
        el.textContent = `${startTime} — ${endTime}`
      })
    }
    if (this.hasTotalTarget) {
      this.totalTargets.forEach((el) => {
        el.textContent = formatCLP(totalCents)
      })
    }
  }

  showQuoteError(message) {
    this.setConfirmSubmitEnabled(false)
    if (this.hasQuotePanelTarget) {
      this.quotePanelTargets.forEach((el) => el.classList.add("hidden"))
    }
    if (this.hasQuoteErrorTarget) {
      this.quoteErrorTargets.forEach((el) => {
        el.textContent = message
        el.classList.remove("hidden")
      })
    }
    if (this.hasTotalTarget) {
      this.totalTargets.forEach((el) => {
        el.textContent = "—"
      })
    }
  }

  updateModePriceLabels() {
    if (!this.hasModePriceTarget) return

    const dateIso = this.dateValue()
    this.modePriceTargets.forEach((el) => {
      const mode = el.dataset.mode
      el.textContent = this.modePriceLabel(mode, dateIso) || ""
    })
  }

  modePriceLabel(mode, dateIso) {
    if (mode === "bloque") {
      const totals = (this.slotRatesValue || [])
        .map((rate) => {
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
          return issue ? null : rate.block_price
        })
        .filter((value) => value != null)

      if (totals.length === 0) {
        const listPrices = (this.slotRatesValue || []).map((r) => r.block_price)
        if (listPrices.length === 0) return null
        const min = Math.min(...listPrices)
        const max = Math.max(...listPrices)
        return min === max ? formatCLP(min) : `${formatCLP(min)}–${formatCLP(max)}`
      }

      const min = Math.min(...totals)
      const max = Math.max(...totals)
      return min === max ? formatCLP(min) : `${formatCLP(min)}–${formatCLP(max)}`
    }

    if (mode === "jornada") {
      const jornada = this.jornadaValue
      if (!jornada?.price) return null
      const issue = periodWindowIssue(
        this.blocksByDayValue,
        this.overridesValue,
        this.reservedIntervalsValue,
        dateIso,
        jornada.start,
        jornada.end,
        this.todayValue,
        this.nowTimeValue
      )
      return issue ? formatCLP(jornada.price) : formatCLP(jornada.price)
    }

    const slotCount = parseInt(this.formField("slot_count")?.value || this.minimumSlotsValue, 10)
    const startTime = this.formField("start_time")?.value || ""
    const total = calculateHourlyTotal(
      this.blocksByDayValue,
      this.overridesValue,
      this.reservedIntervalsValue,
      dateIso,
      slotCount,
      startTime,
      this.todayValue,
      this.nowTimeValue
    )
    return total > 0 ? formatCLP(total + this.equipmentExtraCents(slotCount)) : null
  }

  showLoading(event) {
    if (event && this.isPrefetchRequest(event)) return
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
  }

  hideLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
    this.applyModeUI(this.currentMode())
    this.refreshClientState()
  }

  isPrefetchRequest(event) {
    const headers = event.detail?.fetchOptions?.headers
    if (!headers) return false
    if (typeof headers.get === "function") {
      return headers.get("X-Sec-Purpose") === "prefetch"
    }
    return headers["X-Sec-Purpose"] === "prefetch"
  }

  setConfirmSubmitEnabled(enabled) {
    if (!this.hasConfirmSubmitTarget) return
    this.confirmSubmitTargets.forEach((el) => {
      el.disabled = !enabled
      el.setAttribute("aria-disabled", enabled ? "false" : "true")
    })
  }
}
