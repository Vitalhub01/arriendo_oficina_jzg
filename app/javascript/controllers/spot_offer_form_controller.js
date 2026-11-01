import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "field",
    "weekday",
    "startTime",
    "endTime",
    "startsOn",
    "endsOn",
    "endsOnPanel",
    "weeksPanel",
    "weekCount",
    "periodMode",
    "previewSummary",
    "previewList",
    "previewPricing"
  ]

  static values = {
    previewUrl: String,
    morningStart: String,
    morningEnd: String,
    afternoonStart: String,
    afternoonEnd: String
  }

  connect() {
    this.previewTimer = null
    this.periodModeChanged()
    this.scheduleChanged()
  }

  selectWeekdays(event) {
    const mode = event.params.days
    const presets = {
      weekdays: [0, 1, 2, 3, 4],
      all: [0, 1, 2, 3, 4, 5, 6],
      none: []
    }
    const selected = presets[mode] || []
    this.weekdayTargets.forEach((input) => {
      input.checked = selected.includes(parseInt(input.value, 10))
    })
    this.scheduleChanged()
  }

  applyTimePreset(event) {
    const preset = event.params.preset
    if (preset === "morning") {
      this.startTimeTarget.value = this.morningStartValue
      this.endTimeTarget.value = this.morningEndValue
    } else if (preset === "afternoon") {
      this.startTimeTarget.value = this.afternoonStartValue
      this.endTimeTarget.value = this.afternoonEndValue
    }
    this.scheduleChanged()
  }

  periodModeChanged() {
    const mode = this.currentPeriodMode()
    const useWeeks = mode === "weeks"
    this.endsOnPanelTarget.classList.toggle("hidden", useWeeks)
    this.weeksPanelTarget.classList.toggle("hidden", !useWeeks)
    if (useWeeks) this.syncEndsOnFromWeeks()
    this.scheduleChanged()
  }

  weekCountChanged() {
    this.syncEndsOnFromWeeks()
    this.scheduleChanged()
  }

  scheduleChanged() {
    clearTimeout(this.previewTimer)
    this.previewTimer = setTimeout(() => this.fetchPreview(), 350)
  }

  currentPeriodMode() {
    return this.periodModeTargets.find((el) => el.checked)?.value || "until_date"
  }

  syncEndsOnFromWeeks() {
    const startValue = this.startsOnTarget.value
    const weeks = parseInt(this.weekCountTarget.value, 10)
    if (!startValue || !weeks || weeks < 1) return

    const start = new Date(`${startValue}T12:00:00`)
    const end = new Date(start)
    end.setDate(end.getDate() + weeks * 7 - 1)
    this.endsOnTarget.value = end.toISOString().slice(0, 10)
  }

  async fetchPreview() {
    if (this.currentPeriodMode() === "weeks") this.syncEndsOnFromWeeks()

    const formData = new FormData(this.element)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    this.previewSummaryTarget.textContent = "Calculando sesiones disponibles…"

    try {
      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": token
        },
        body: formData
      })

      if (!response.ok) {
        this.previewSummaryTarget.textContent = "No se pudo calcular la vista previa."
        return
      }

      const data = await response.json()
      this.renderPreview(data)
    } catch {
      this.previewSummaryTarget.textContent = "No se pudo calcular la vista previa."
    }
  }

  renderPreview(data) {
    const count = data.count || 0

    if (count === 0) {
      this.previewSummaryTarget.textContent =
        "No hay sesiones disponibles con esta combinación (revisa días, horario o espacio)."
      this.previewListTarget.classList.add("hidden")
      this.previewListTarget.innerHTML = ""
      this.previewPricingTarget.classList.add("hidden")
      return
    }

    const summary = data.summary || `${count} sesiones`
    this.previewSummaryTarget.textContent = `${count} sesiones · ${summary}`

    this.previewListTarget.innerHTML = (data.samples || [])
      .map((row) => `<li>${row.date} · ${row.time}</li>`)
      .join("")
    this.previewListTarget.classList.toggle("hidden", !(data.samples || []).length)

    if (data.total_label && data.per_session_label) {
      this.previewPricingTarget.textContent = `Total ${data.total_label} · ~${data.per_session_label} por sesión`
      this.previewPricingTarget.classList.remove("hidden")
    } else {
      this.previewPricingTarget.classList.add("hidden")
    }
  }
}
