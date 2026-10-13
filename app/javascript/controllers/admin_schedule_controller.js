import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dialog", "form", "blockId", "dayOfWeek", "name", "startTime", "endTime",
    "priceClp", "durationHint", "deleteButton", "error", "toast", "dialogTitle"
  ]
  static values = {
    blocks: Array,
    spaceId: Number,
    defaultPrice: Number,
    slotDuration: Number,
    csrf: String,
    calendarStart: Number,
    calendarEnd: Number
  }

  openNew(event) {
    const day = parseInt(event.currentTarget.dataset.day, 10)
    this.blockIdTarget.value = ""
    this.dayOfWeekTarget.value = day
    this.nameTarget.value = ""
    this.startTimeTarget.value = "09:00"
    const endMinutes = 9 * 60 + this.slotDurationValue
    this.endTimeTarget.value = this.minutesToTime(endMinutes)
    this.priceClpTarget.value = Math.round(this.defaultPriceValue / 100)
    this.deleteButtonTarget.classList.add("hidden")
    this.dialogTitleTarget.textContent = `Nuevo bloque — ${this.dayName(day)}`
    this.updateDurationHint()
    this.errorTarget.classList.add("hidden")
    this.dialogTarget.showModal()
  }

  openEdit(event) {
    const id = parseInt(event.currentTarget.dataset.blockId, 10)
    const block = this.blocksValue.find((b) => b.id === id)
    if (!block) return

    this.blockIdTarget.value = block.id
    this.dayOfWeekTarget.value = block.day_of_week
    this.nameTarget.value = block.name || ""
    this.startTimeTarget.value = block.start_time
    this.endTimeTarget.value = block.end_time
    this.priceClpTarget.value = Math.round(block.price_clp)
    this.deleteButtonTarget.classList.remove("hidden")
    this.dialogTitleTarget.textContent = "Editar bloque"
    this.updateDurationHint()
    this.errorTarget.classList.add("hidden")
    this.dialogTarget.showModal()
  }

  closeDialog() {
    this.dialogTarget.close()
  }

  updateDurationHint() {
    const start = this.parseTime(this.startTimeTarget.value)
    const end = this.parseTime(this.endTimeTarget.value)
    if (end > start) {
      this.durationHintTarget.textContent = `Duración: ${end - start} minutos`
    } else {
      this.durationHintTarget.textContent = ""
    }
  }

  startTimeTargetConnected() {
    this.startTimeTarget?.addEventListener("change", () => this.updateDurationHint())
    this.endTimeTarget?.addEventListener("change", () => this.updateDurationHint())
  }

  async save(event) {
    event.preventDefault()
    const id = this.blockIdTarget.value
    const body = {
      schedule_block: {
        day_of_week: parseInt(this.dayOfWeekTarget.value, 10),
        name: this.nameTarget.value,
        start_time: this.startTimeTarget.value,
        end_time: this.endTimeTarget.value,
        price_clp: this.priceClpTarget.value
      }
    }

    const url = id
      ? `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}`
      : `/admin/spaces/${this.spaceIdValue}/schedule_blocks`
    const method = id ? "PATCH" : "POST"

    const response = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfValue,
        Accept: "application/json"
      },
      body: JSON.stringify(body)
    })

    if (response.ok) {
      this.showToast()
      window.location.reload()
    } else {
      const data = await response.json()
      this.errorTarget.textContent = (data.errors || ["Error al guardar"]).join(", ")
      this.errorTarget.classList.remove("hidden")
    }
  }

  async destroy() {
    const id = this.blockIdTarget.value
    if (!id || !confirm("¿Eliminar este bloque?")) return

    const response = await fetch(`/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": this.csrfValue,
        Accept: "application/json"
      }
    })

    if (response.ok) {
      this.showToast()
      window.location.reload()
    }
  }

  showToast() {
    this.toastTarget.classList.remove("hidden")
  }

  dayName(day) {
    return ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"][day]
  }

  parseTime(str) {
    const [h, m] = str.split(":").map((v) => parseInt(v, 10))
    return h * 60 + m
  }

  minutesToTime(minutes) {
    const h = Math.floor(minutes / 60)
    const m = minutes % 60
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`
  }
}
