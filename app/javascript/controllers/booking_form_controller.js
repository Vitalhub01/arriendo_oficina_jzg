import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hours", "total", "pricePerHour"]
  static values = { pricePerHour: Number }

  connect() {
    this.updateTotal()
  }

  updateTotal() {
    const hours = parseInt(this.hoursTarget.value || 1, 10)
    const total = hours * this.pricePerHourValue
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = this.formatCLP(total)
    }
  }

  increment() {
    this.hoursTarget.value = parseInt(this.hoursTarget.value || 1, 10) + 1
    this.updateTotal()
  }

  decrement() {
    const current = parseInt(this.hoursTarget.value || 1, 10)
    if (current > 1) {
      this.hoursTarget.value = current - 1
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
