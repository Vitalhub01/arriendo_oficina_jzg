import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slotCount", "total", "startTime", "durationLabel", "date"]
  static values = {
    minimumSlots: Number,
    blocksByDay: Object,
    overrides: Array,
    today: String,
    nowTime: String
  }

  connect() {
    this.refreshStarts()
    this.updateTotal()
  }

  selectSlot(event) {
    const { date, startTime } = event.currentTarget.dataset
    if (!date || !startTime) return

    this.dateTargets.forEach((field) => {
      field.value = date
    })
    this.refreshStarts()
    this.startTimeTargets.forEach((select) => {
      select.value = startTime
    })
    this.updateTotal()

    const mobileSheet = document.getElementById("booking-form-mobile")
    if (mobileSheet && window.matchMedia("(max-width: 1023px)").matches) {
      mobileSheet.classList.remove("hidden")
      mobileSheet.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  refreshStarts() {
    if (!this.hasStartTimeTarget || !this.hasDateTarget) return

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
        !this.isPastBlock(block, dateIso)
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
        option.textContent = "Sin bloques disponibles"
        select.appendChild(option)
      } else if (previous && selectableBlocks.some((b) => b.start === previous)) {
        select.value = previous
      }
    })
  }

  updateTotal() {
    const slotCount = parseInt(this.slotCountTargets[0]?.value || this.minimumSlotsValue, 10)
    const startTime = this.hasStartTimeTarget ? this.startTimeTargets[0]?.value : ""
    const total = this.calculateTotal(slotCount, startTime)
    const durationMinutes = this.totalDurationMinutes(slotCount, startTime)

    this.totalTargets.forEach((el) => {
      el.textContent = this.formatCLP(total)
    })

    if (this.hasDurationLabelTarget) {
      const hours = Math.floor(durationMinutes / 60)
      const minutes = durationMinutes % 60
      let label = `Duración: ${durationMinutes} min`
      if (hours > 0 && minutes > 0) {
        label = `Duración: ${hours}h ${minutes}min`
      } else if (hours > 0) {
        label = `Duración: ${hours} hora(s)`
      }
      this.durationLabelTargets.forEach((el) => {
        el.textContent = label
      })
    }
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
    const field = this.slotCountTargets[0]
    if (!field) return
    const next = parseInt(field.value || this.minimumSlotsValue, 10) + 1
    this.slotCountTargets.forEach((el) => {
      el.value = next
    })
    this.updateTotal()
  }

  decrement() {
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
