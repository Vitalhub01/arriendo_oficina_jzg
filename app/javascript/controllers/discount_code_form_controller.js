import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["weekday", "startTime", "endTime", "percentField", "amountField", "discountType"]

  static values = {
    morningStart: { type: String, default: "08:00" },
    morningEnd: { type: String, default: "12:00" }
  }

  connect() {
    if (this.hasDiscountTypeTarget) this.discountTypeChanged()
  }

  selectWeekdays(event) {
    const mode = event.params.days
    const presets = {
      weekdays: [0, 1, 2, 3, 4],
      mon_thu: [0, 1, 2, 3],
      all: [0, 1, 2, 3, 4, 5, 6],
      none: []
    }
    const selected = presets[mode] || []
    this.weekdayTargets.forEach((input) => {
      input.checked = selected.includes(parseInt(input.value, 10))
    })
  }

  applyTimePreset(event) {
    if (!this.hasStartTimeTarget || !this.hasEndTimeTarget) return

    const preset = event.params.preset
    if (preset === "morning") {
      this.startTimeTarget.value = this.morningStartValue
      this.endTimeTarget.value = this.morningEndValue
    } else if (preset === "clear") {
      this.startTimeTarget.value = ""
      this.endTimeTarget.value = ""
    }
    this.startTimeTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.endTimeTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  discountTypeChanged() {
    if (!this.hasDiscountTypeTarget || !this.hasPercentFieldTarget || !this.hasAmountFieldTarget) return

    const type = this.discountTypeTarget.value
    const isPercent = type === "percent"
    this.percentFieldTarget.classList.toggle("hidden", !isPercent)
    this.amountFieldTarget.classList.toggle("hidden", isPercent)
  }
}
