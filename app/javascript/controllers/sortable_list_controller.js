import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "status"]

  static values = {
    reorderUrl: String,
    csrfToken: String
  }

  connect() {
    this.draggedId = null
  }

  dragStart(event) {
    const row = event.currentTarget.closest("[data-sortable-list-target='row']")
    if (!row) return

    this.draggedId = row.dataset.sortableId
    row.classList.add("opacity-50")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedId)
  }

  dragEnd(event) {
    const row = event.currentTarget.closest("[data-sortable-list-target='row']")
    row?.classList.remove("opacity-50")
    this.draggedId = null
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const row = event.target.closest("[data-sortable-list-target='row']")
    if (!row || row.dataset.sortableId === this.draggedId) return

    const rect = row.getBoundingClientRect()
    const before = event.clientY < rect.top + rect.height / 2
    const dragged = this.element.querySelector(`[data-sortable-id='${this.draggedId}']`)
    if (!dragged) return

    const parent = row.parentNode
    if (before) {
      parent.insertBefore(dragged, row)
    } else {
      parent.insertBefore(dragged, row.nextSibling)
    }
  }

  async dropOnList(event) {
    event.preventDefault()
    await this.syncOrder()
  }

  async syncOrder() {
    const ids = this.rowTargets.map((row) => row.dataset.sortableId)
    if (!this.reorderUrlValue || ids.length === 0) return

    try {
      const response = await fetch(this.reorderUrlValue, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfTokenValue
        },
        body: JSON.stringify({ order: ids })
      })
      if (!response.ok) throw new Error("reorder failed")
      this.setStatus("Orden guardado")
    } catch (_error) {
      this.setStatus("No se pudo guardar el orden")
    }
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    window.clearTimeout(this.statusTimeout)
    this.statusTimeout = window.setTimeout(() => {
      this.statusTarget.textContent = ""
    }, 2500)
  }
}
