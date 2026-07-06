import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slotCount", "total", "startTime", "durationLabel"]
  static values = {
    slotDuration: Number,
    minimumSlots: Number,
    defaultPrice: Number,
    rates: Array
  }

  connect() {
    this.updateTotal()
  }

  updateTotal() {
    const slotCount = parseInt(this.slotCountTarget.value || this.minimumSlotsValue, 10)
    const startTime = this.hasStartTimeTarget ? this.startTimeTarget.value : "09:00"
    const total = this.calculateTotal(slotCount, startTime)

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = this.formatCLP(total)
    }

    if (this.hasDurationLabelTarget) {
      const totalMinutes = slotCount * this.slotDurationValue
      const hours = Math.floor(totalMinutes / 60)
      const minutes = totalMinutes % 60
      let label = `Duración: ${totalMinutes} min`
      if (hours > 0 && minutes > 0) {
        label = `Duración: ${hours}h ${minutes}min`
      } else if (hours > 0) {
        label = `Duración: ${hours} hora(s)`
      }
      this.durationLabelTarget.textContent = label
    }
  }

  calculateTotal(slotCount, startTime) {
    const [startHour, startMin] = startTime.split(":").map((v) => parseInt(v, 10))
    let currentMinutes = startHour * 60 + startMin
    let total = 0

    for (let i = 0; i < slotCount; i++) {
      total += this.priceForMinute(currentMinutes)
      currentMinutes += this.slotDurationValue
    }

    return total
  }

  priceForMinute(minutesFromMidnight) {
    const timeStr = this.minutesToTime(minutesFromMidnight)
    const rate = this.ratesValue.find((r) => timeStr >= r.start && timeStr < r.end)
    return rate ? rate.price : this.defaultPriceValue
  }

  minutesToTime(minutes) {
    const hours = Math.floor(minutes / 60)
    const mins = minutes % 60
    return `${String(hours).padStart(2, "0")}:${String(mins).padStart(2, "0")}`
  }

  increment() {
    this.slotCountTarget.value = parseInt(this.slotCountTarget.value || this.minimumSlotsValue, 10) + 1
    this.updateTotal()
  }

  decrement() {
    const current = parseInt(this.slotCountTarget.value || this.minimumSlotsValue, 10)
    if (current > this.minimumSlotsValue) {
      this.slotCountTarget.value = current - 1
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
