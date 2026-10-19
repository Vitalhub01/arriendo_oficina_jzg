import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list",
    "item",
    "orderInput",
    "fileInput",
    "dropZone",
    "emptyState",
    "status"
  ]

  static values = {
    createUrl: String,
    reorderUrl: String,
    updateUrlTemplate: String,
    destroyUrlTemplate: String,
    showTag: { type: Boolean, default: false },
    csrfToken: String
  }

  connect() {
    this.draggedId = null
    this.uploadQueue = Promise.resolve()
  }

  browseFiles() {
    this.fileInputTarget.click()
  }

  preventDefaults(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  highlightDropZone() {
    this.dropZoneTarget.classList.add("ring-2", "ring-brand", "bg-brand-pale/40")
  }

  unhighlightDropZone() {
    this.dropZoneTarget.classList.remove("ring-2", "ring-brand", "bg-brand-pale/40")
  }

  handleDrop(event) {
    this.preventDefaults(event)
    this.unhighlightDropZone()
    const files = Array.from(event.dataTransfer?.files || [])
    this.uploadFiles(files)
  }

  handleFileSelect(event) {
    const files = Array.from(event.target.files || [])
    event.target.value = ""
    this.uploadFiles(files)
  }

  uploadFiles(files) {
    const images = files.filter((file) => file.type.startsWith("image/"))
    if (images.length === 0) return

    images.forEach((file) => {
      this.uploadQueue = this.uploadQueue.then(() => this.uploadOne(file))
    })
  }

  async uploadOne(file) {
    this.setStatus("Subiendo foto…")

    const body = new FormData()
    body.append("image", file)
    if (this.showTagValue) {
      body.append("gallery_item[tag]", "")
    }

    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: this.jsonHeaders(),
        body
      })

      if (!response.ok) throw new Error("upload failed")

      const data = await response.json()
      this.insertItem(data)
      this.syncOrder()
      this.setStatus("Foto agregada")
    } catch (_error) {
      this.setStatus("No se pudo subir la foto. Intenta de nuevo.")
    }
  }

  insertItem(data) {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add("hidden")
    }

    const wrapper = document.createElement("div")
    wrapper.innerHTML = data.html.trim()
    const element = wrapper.firstElementChild
    this.listTarget.appendChild(element)
  }

  dragStart(event) {
    const item = event.currentTarget.closest("[data-photo-manager-target='item']")
    if (!item) return

    this.draggedId = item.dataset.photoId
    item.classList.add("opacity-50")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedId)
  }

  dragEnd(event) {
    const item = event.currentTarget.closest("[data-photo-manager-target='item']")
    item?.classList.remove("opacity-50")
    this.draggedId = null
  }

  dragOver(event) {
    this.preventDefaults(event)
    event.dataTransfer.dropEffect = "move"

    const item = event.target.closest("[data-photo-manager-target='item']")
    if (!item || item.dataset.photoId === this.draggedId) return

    const rect = item.getBoundingClientRect()
    const before = event.clientY < rect.top + rect.height / 2
    const dragged = this.listTarget.querySelector(`[data-photo-id='${this.draggedId}']`)
    if (!dragged) return

    if (before) {
      this.listTarget.insertBefore(dragged, item)
    } else {
      this.listTarget.insertBefore(dragged, item.nextSibling)
    }
  }

  async dropOnList(event) {
    this.preventDefaults(event)
    await this.syncOrder()
  }

  async syncOrder() {
    const ids = this.itemTargets.map((item) => item.dataset.photoId)
    if (this.hasOrderInputTarget) {
      this.orderInputTarget.value = ids.join(",")
    }

    if (!this.reorderUrlValue) return

    try {
      const response = await fetch(this.reorderUrlValue, {
        method: "PATCH",
        headers: this.jsonHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({ order: ids })
      })
      if (!response.ok) throw new Error("reorder failed")
      this.refreshCoverBadges()
      this.setStatus("Orden guardado")
    } catch (_error) {
      this.setStatus("No se pudo guardar el orden")
    }
  }

  async saveAlt(event) {
    const item = event.target.closest("[data-photo-manager-target='item']")
    if (!item) return

    const id = item.dataset.photoId
    const url = this.updateUrlTemplateValue.replace(":id", id)
    const alt_text = event.target.value

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: this.jsonHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({ alt_text })
      })
      if (!response.ok) throw new Error("update failed")
      this.setStatus("Texto alternativo guardado")
    } catch (_error) {
      this.setStatus("No se pudo guardar el texto alternativo")
    }
  }

  async saveTag(event) {
    const item = event.target.closest("[data-photo-manager-target='item']")
    if (!item) return

    const id = item.dataset.photoId
    const url = this.updateUrlTemplateValue.replace(":id", id)
    const tag = event.target.value

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: this.jsonHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({ tag })
      })
      if (!response.ok) throw new Error("update failed")
      this.setStatus("Etiqueta guardada")
    } catch (_error) {
      this.setStatus("No se pudo guardar la etiqueta")
    }
  }

  async saveCaption(event) {
    const item = event.target.closest("[data-photo-manager-target='item']")
    if (!item) return

    const id = item.dataset.photoId
    const url = this.updateUrlTemplateValue.replace(":id", id)
    const caption = event.target.value

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: this.jsonHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({ caption })
      })
      if (!response.ok) throw new Error("update failed")
      this.setStatus("Descripción guardada")
    } catch (_error) {
      this.setStatus("No se pudo guardar la descripción")
    }
  }

  async removePhoto(event) {
    const item = event.currentTarget.closest("[data-photo-manager-target='item']")
    if (!item) return

    if (!window.confirm("¿Eliminar esta foto?")) return

    const id = item.dataset.photoId
    const url = this.destroyUrlTemplateValue.replace(":id", id)

    try {
      const response = await fetch(url, {
        method: "DELETE",
        headers: this.jsonHeaders()
      })
      if (!response.ok) throw new Error("destroy failed")

      item.remove()
      await this.syncOrder()
      this.setStatus("Foto eliminada")

      if (this.itemTargets.length === 0 && this.hasEmptyStateTarget) {
        this.emptyStateTarget.classList.remove("hidden")
      }
    } catch (_error) {
      this.setStatus("No se pudo eliminar la foto")
    }
  }

  jsonHeaders(extra = {}) {
    return {
      Accept: "application/json",
      "X-CSRF-Token": this.csrfTokenValue,
      ...extra
    }
  }

  refreshCoverBadges() {
    this.itemTargets.forEach((item, index) => {
      item.querySelectorAll("[data-cover-badge]").forEach((badge) => {
        badge.classList.toggle("hidden", index !== 0)
      })
    })
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
