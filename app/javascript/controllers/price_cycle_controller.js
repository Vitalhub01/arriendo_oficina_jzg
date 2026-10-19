import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "period"]
  static values = {
    items: { type: Array, default: [] },
    interval: { type: Number, default: 3500 }
  }

  connect() {
    if (this.itemsValue.length < 2) return

    this.index = 0
    this.timer = window.setInterval(() => this.advance(), this.intervalValue)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }

  advance() {
    this.index = (this.index + 1) % this.itemsValue.length
    this.fadeTo(this.itemsValue[this.index])
  }

  fadeTo(item) {
    this.amountTarget.classList.add("opacity-0", "translate-y-1")
    if (this.hasPeriodTarget) this.periodTarget.classList.add("opacity-0")

    window.setTimeout(() => {
      this.amountTarget.textContent = item.amount
      if (this.hasPeriodTarget) this.periodTarget.textContent = item.label
      this.amountTarget.classList.remove("opacity-0", "translate-y-1")
      if (this.hasPeriodTarget) this.periodTarget.classList.remove("opacity-0")
    }, 220)
  }
}
