import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slotCount", "total", "startTime", "durationLabel", "date"]
  static values = {
    minimumSlots: Number,
    blocksByDay: Object
  }

  connect() {
    this.refreshStarts()
    this.updateTotal()
  }

  refreshStarts() {
    if (!this.hasStartTimeTarget || !this.hasDateTarget) return

    const date = new Date(this.dateTarget.value + "T12:00:00")
    const day = (date.getDay() + 6) % 7
    const blocks = this.blocksByDayValue[String(day)] || []

    const select = this.startTimeTarget
    const previous = select.value
    select.innerHTML = ""

    blocks.forEach((block) => {
      const option = document.createElement("option")
      option.value = block.start
      option.textContent = `${block.start} – ${block.end} (${this.formatCLP(block.price)})`
      select.appendChild(option)
    })

    if (blocks.length === 0) {
      const option = document.createElement("option")
      option.value = ""
      option.textContent = "Sin bloques este día"
      select.appendChild(option)
    } else if (previous && blocks.some((b) => b.start === previous)) {
      select.value = previous
    }
  }

  updateTotal() {
    const slotCount = parseInt(this.slotCountTarget.value || this.minimumSlotsValue, 10)
    const startTime = this.hasStartTimeTarget ? this.startTimeTarget.value : ""
    const total = this.calculateTotal(slotCount, startTime)
    const durationMinutes = this.totalDurationMinutes(slotCount, startTime)

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = this.formatCLP(total)
    }

    if (this.hasDurationLabelTarget) {
      const hours = Math.floor(durationMinutes / 60)
      const minutes = durationMinutes % 60
      let label = `Duración: ${durationMinutes} min`
      if (hours > 0 && minutes > 0) {
        label = `Duración: ${hours}h ${minutes}min`
      } else if (hours > 0) {
        label = `Duración: ${hours} hora(s)`
      }
      this.durationLabelTarget.textContent = label
    }
  }

  calculateTotal(slotCount, startTime) {
    const blocks = this.blocksForStart(startTime)
    if (blocks.length === 0) return 0

    const startIndex = blocks.findIndex((b) => b.start === startTime)
    if (startIndex < 0) return 0

    let total = 0
    for (let i = 0; i < slotCount; i++) {
      const block = blocks[startIndex + i]
      if (!block) return 0
      if (i > 0 && blocks[startIndex + i - 1].end !== block.start) return 0
      total += block.price
    }
    return total
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
    const date = new Date(this.dateTarget.value + "T12:00:00")
    const day = (date.getDay() + 6) % 7
    return this.blocksByDayValue[String(day)] || []
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
