import { Controller } from "@hotwired/stimulus"

// Evita que el scroll del mouse incremente/decremente inputs type=number mientras están enfocados.
export default class extends Controller {
  connect() {
    this.onWheel = this.onWheel.bind(this)
    this.numberInputs().forEach((input) => {
      input.addEventListener("wheel", this.onWheel, { passive: false })
    })
  }

  disconnect() {
    this.numberInputs().forEach((input) => {
      input.removeEventListener("wheel", this.onWheel)
    })
  }

  numberInputs() {
    return this.element.querySelectorAll('input[type="number"]')
  }

  onWheel(event) {
    if (event.currentTarget === document.activeElement) {
      event.preventDefault()
    }
  }
}
