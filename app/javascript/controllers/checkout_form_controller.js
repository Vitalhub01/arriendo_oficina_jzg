import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }

  submitDebounced() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.element.requestSubmit(), 350)
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }
}
