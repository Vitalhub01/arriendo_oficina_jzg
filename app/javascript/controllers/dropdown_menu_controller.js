import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "trigger"]

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  disconnect() {
    this.removeDocumentListeners()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "true")
    }
    document.addEventListener("click", this.closeOnClickOutside)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "false")
    }
    this.removeDocumentListeners()
  }

  isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  removeDocumentListeners() {
    document.removeEventListener("click", this.closeOnClickOutside)
    document.removeEventListener("keydown", this.closeOnEscape)
  }
}
