import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dialog", "form", "blockId", "dayOfWeek", "name", "startTime", "endTime",
    "priceClp", "durationHint", "deleteButton", "error", "toast", "dialogTitle",
    "dialogSubtitle", "occurrenceDate", "datePriceClp", "dateStartTime", "dateEndTime",
    "dateTimeHint", "dateStatus",
    "tabBar", "tabDate", "tabTemplate", "panelDate", "panelTemplate"
  ]
  static values = {
    blocks: Array,
    overrides: Array,
    weekDates: Array,
    spaceId: Number,
    weekStart: String,
    defaultPrice: Number,
    slotDuration: Number,
    csrf: String,
    calendarStart: Number,
    calendarEnd: Number
  }

  static classes = {
    tabActive: ["border-gray-300", "border-b-white", "bg-white", "text-gray-900", "shadow-sm"],
    tabInactive: ["border-transparent", "bg-transparent", "text-gray-600", "hover:bg-gray-200/80"]
  }

  connect() {
    this.startTimeTarget?.addEventListener("change", () => this.updateDurationHint())
    this.endTimeTarget?.addEventListener("change", () => this.updateDurationHint())
    this.activeTab = "template"
  }

  openNew(event) {
    const day = parseInt(event.currentTarget.dataset.day, 10)
    const date = this.weekDatesValue[day] || ""

    this.blockIdTarget.value = ""
    this.dayOfWeekTarget.value = day
    this.nameTarget.value = ""
    this.startTimeTarget.value = "09:00"
    this.endTimeTarget.value = this.minutesToTime(9 * 60 + this.slotDurationValue)
    this.priceClpTarget.value = Math.round(this.defaultPriceValue)
    this.deleteButtonTarget.classList.add("hidden")
    this.dialogTitleTarget.textContent = `Nuevo bloque — ${this.dayName(day)}`
    this.dialogSubtitleTarget.textContent = date ? this.formatDateLabel(date) : ""
    this.setDateTabAvailable(false)
    this.selectTab("template")
    this.updateDurationHint()
    this.hideError()
    this.dialogTarget.showModal()
  }

  openEdit(event) {
    event.preventDefault()
    event.stopPropagation()

    const id = parseInt(event.currentTarget.dataset.blockId, 10)
    const date = event.currentTarget.dataset.date || ""
    const block = this.blocksValue.find((b) => String(b.id) === String(id))
    if (!block) return

    this.blockIdTarget.value = block.id
    this.dayOfWeekTarget.value = block.day_of_week
    this.nameTarget.value = block.name || ""
    this.startTimeTarget.value = block.start_time
    this.endTimeTarget.value = block.end_time
    this.priceClpTarget.value = block.price_clp ?? block.price_cents
    this.deleteButtonTarget.classList.remove("hidden")

    const dayLabel = this.dayName(block.day_of_week)
    this.dialogTitleTarget.textContent = `${block.start_time} – ${block.end_time}`
    this.dialogSubtitleTarget.textContent = date
      ? `${dayLabel} ${this.formatDateLabel(date)}`
      : `Todos los ${dayLabel}`

    if (date) {
      this.setDateTabAvailable(true)
      this.populateDatePanel(id, date, block)
      this.selectTab("date")
    } else {
      this.setDateTabAvailable(false)
      this.selectTab("template")
    }

    this.updateDurationHint()
    this.hideError()
    this.dialogTarget.showModal()
  }

  selectTab(eventOrName) {
    const tab = typeof eventOrName === "string" ? eventOrName : eventOrName.currentTarget.dataset.tab
    this.activeTab = tab

    const isDate = tab === "date"
    this.panelDateTarget.classList.toggle("hidden", !isDate)
    this.panelTemplateTarget.classList.toggle("hidden", isDate)

    this.styleTab(this.tabDateTarget, isDate)
    this.styleTab(this.tabTemplateTarget, !isDate)

    if (this.hasTabDateTarget) {
      this.tabDateTarget.setAttribute("aria-selected", isDate ? "true" : "false")
    }
    this.tabTemplateTarget.setAttribute("aria-selected", !isDate ? "true" : "false")
  }

  styleTab(element, active) {
    if (!element) return
    element.classList.remove(
      "border-gray-300", "border-b-white", "bg-white", "text-gray-900", "shadow-sm",
      "border-transparent", "bg-transparent", "text-gray-600", "hover:bg-gray-200/80"
    )
    if (active) {
      element.classList.add("border", "border-b-0", "border-gray-300", "border-b-white", "bg-white", "text-gray-900", "shadow-sm")
    } else {
      element.classList.add("border", "border-b-0", "border-transparent", "text-gray-600", "hover:bg-gray-200/80")
    }
  }

  setDateTabAvailable(available) {
    if (!this.hasTabDateTarget) return
    this.tabDateTarget.classList.toggle("hidden", !available)
    if (!available && this.activeTab === "date") {
      this.selectTab("template")
    }
  }

  populateDatePanel(blockId, date, block) {
    this.occurrenceDateTarget.value = date
    const override = this.findOverride(blockId, date)

    const templateStart = block.start_time
    const templateEnd = block.end_time
    const start = override?.start_time || templateStart
    const end = override?.end_time || templateEnd

    this.dateStartTimeTarget.value = start
    this.dateEndTimeTarget.value = end
    this.updateDateTimeHint(block, override)

    if (override?.blocked) {
      this.dateStatusTarget.textContent = "Este horario está bloqueado en esta fecha."
      this.datePriceClpTarget.value = ""
    } else if (override?.price_clp || override?.price_cents) {
      const price = override.price_clp ?? override.price_cents
      this.dateStatusTarget.textContent = `Precio especial: ${this.formatCLP(price)}`
      this.datePriceClpTarget.value = Math.round(price)
    } else {
      this.dateStatusTarget.textContent = `Precio de plantilla: ${this.formatCLP(block.price_cents)}`
      this.datePriceClpTarget.value = ""
    }
  }

  updateDateTimeHint(block, override) {
    const customTimes = override?.start_time || override?.end_time
    const templateLabel = `${block.start_time} – ${block.end_time}`
    if (customTimes) {
      this.dateTimeHintTarget.textContent = `Plantilla semanal: ${templateLabel}. Ajusta arriba solo para este día.`
    } else {
      this.dateTimeHintTarget.textContent = `Igual que plantilla (${templateLabel}). Cambia inicio/fin si necesitas otra ventana solo hoy.`
    }
  }

  findOverride(blockId, date) {
    return this.overridesValue.find(
      (o) => String(o.schedule_block_id) === String(blockId) && o.date === date
    )
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

  async save(event) {
    event.preventDefault()
    const id = this.blockIdTarget.value
    const dayOfWeek = parseInt(this.dayOfWeekTarget.value, 10)
    const startTime = this.startTimeTarget.value
    const endTime = this.endTimeTarget.value

    const overlapping = this.findOverlapping(dayOfWeek, startTime, endTime, id)
    let removeIds = []

    if (overlapping.length > 0) {
      const labels = overlapping.map((b) => `${b.start_time}–${b.end_time}`).join(", ")
      const message = overlapping.length === 1
        ? `Este horario se solapa con el bloque ${labels} (franja siguiente o anterior). ¿Eliminar ese bloque y guardar?`
        : `Este horario se solapa con: ${labels}. ¿Eliminar esas franjas y guardar?`

      if (!confirm(message)) return
      removeIds = overlapping.map((b) => b.id)
    }

    const body = {
      schedule_block: {
        day_of_week: dayOfWeek,
        name: this.nameTarget.value,
        start_time: startTime,
        end_time: endTime,
        price_clp: this.priceClpTarget.value
      },
      week_start: this.weekStartValue,
      remove_overlapping_ids: removeIds
    }

    const url = id
      ? `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}`
      : `/admin/spaces/${this.spaceIdValue}/schedule_blocks`
    const method = id ? "PATCH" : "POST"

    const response = await this.jsonRequest(url, method, body)
    if (response.ok) {
      this.reloadWithToast()
    } else if (response.errors?.some((e) => e.includes("solapa"))) {
      const retry = await this.promptOverlapRetry(response.errors, dayOfWeek, startTime, endTime, id, body)
      if (retry) this.reloadWithToast()
      else this.showError(response.errors)
    } else {
      this.showError(response.errors)
    }
  }

  async promptOverlapRetry(errors, dayOfWeek, startTime, endTime, id, body) {
    const overlapping = this.findOverlapping(dayOfWeek, startTime, endTime, id)
    if (overlapping.length === 0) return false

    const labels = overlapping.map((b) => `${b.start_time}–${b.end_time}`).join(", ")
    if (!confirm(`Aún hay solapamiento con ${labels}. ¿Eliminar y reintentar?`)) return false

    body.remove_overlapping_ids = overlapping.map((b) => b.id)
    const url = id
      ? `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}`
      : `/admin/spaces/${this.spaceIdValue}/schedule_blocks`
    const method = id ? "PATCH" : "POST"
    const response = await this.jsonRequest(url, method, body)
    return response.ok
  }

  isBlockedOnDate(blockId, date) {
    const override = this.findOverride(blockId, date)
    return override?.blocked === true
  }

  effectiveTimesForBlock(block, date) {
    if (this.isBlockedOnDate(block.id, date)) return null
    const override = this.findOverride(block.id, date)
    return {
      start: override?.start_time || block.start_time,
      end: override?.end_time || block.end_time
    }
  }

  formatBlockIntervalOnDate(block, date) {
    const times = this.effectiveTimesForBlock(block, date)
    if (!times) return ""
    return `${times.start}–${times.end}`
  }

  findOverlappingOnDate(date, startTime, endTime, excludeBlockId) {
    const block = this.blocksValue.find((b) => String(b.id) === String(excludeBlockId))
    if (!block) return []

    const start = this.parseTime(startTime)
    const end = this.parseTime(endTime)
    if (end <= start) return []

    return this.blocksValue
      .filter((other) => {
        if (String(other.id) === String(excludeBlockId)) return false
        if (other.day_of_week !== block.day_of_week) return false

        const times = this.effectiveTimesForBlock(other, date)
        if (!times) return false

        const otherStart = this.parseTime(times.start)
        const otherEnd = this.parseTime(times.end)
        return start < otherEnd && end > otherStart
      })
      .sort((a, b) => {
        const ta = this.effectiveTimesForBlock(a, date)
        const tb = this.effectiveTimesForBlock(b, date)
        return this.parseTime(ta.start) - this.parseTime(tb.start)
      })
  }

  findOverlapping(dayOfWeek, startTime, endTime, excludeId) {
    const start = this.parseTime(startTime)
    const end = this.parseTime(endTime)
    if (end <= start) return []

    return this.blocksValue
      .filter((block) => {
        if (excludeId && String(block.id) === String(excludeId)) return false
        if (block.day_of_week !== dayOfWeek) return false

        const blockStart = this.parseTime(block.start_time)
        const blockEnd = this.parseTime(block.end_time)
        return start < blockEnd && end > blockStart
      })
      .sort((a, b) => this.parseTime(a.start_time) - this.parseTime(b.start_time))
  }

  async saveDateOverride() {
    const id = this.blockIdTarget.value
    const date = this.occurrenceDateTarget.value
    if (!id || !date) return

    const block = this.blocksValue.find((b) => String(b.id) === String(id))
    const price = this.datePriceClpTarget.value.trim()
    const startTime = this.dateStartTimeTarget.value
    const endTime = this.dateEndTimeTarget.value
    const timesChanged = block && (startTime !== block.start_time || endTime !== block.end_time)

    if (!price && !timesChanged) {
      this.showError(["Indica un precio especial o cambia el horario para este día"])
      return
    }

    if (startTime && endTime && this.parseTime(endTime) <= this.parseTime(startTime)) {
      this.showError(["La hora de fin debe ser posterior al inicio"])
      return
    }

    const payload = { date, week_start: this.weekStartValue }
    if (price) payload.price_clp = price
    if (timesChanged) {
      payload.start_time = startTime
      payload.end_time = endTime

      const overlapping = this.findOverlappingOnDate(date, startTime, endTime, id)
      if (overlapping.length > 0) {
        const labels = overlapping
          .map((b) => this.formatBlockIntervalOnDate(b, date))
          .join(", ")
        const message = overlapping.length === 1
          ? `Este horario se solapa en este día con ${labels}. ¿Quitar esa franja solo para esta fecha y guardar?`
          : `Este horario se solapa en este día con: ${labels}. ¿Quitar esas franjas solo para esta fecha y guardar?`

        if (!confirm(message)) return
        payload.block_overlapping_ids = overlapping.map((b) => b.id)
      }
    }

    const response = await this.jsonRequest(
      `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}/override`,
      "POST",
      payload
    )

    if (response.ok) {
      this.reloadWithToast()
    } else if (response.errors?.some((e) => e.includes("solapa"))) {
      const overlapping = this.findOverlappingOnDate(date, startTime, endTime, id)
      if (overlapping.length === 0) {
        this.showError(response.errors)
        return
      }
      const labels = overlapping.map((b) => this.formatBlockIntervalOnDate(b, date)).join(", ")
      if (!confirm(`Aún hay solapamiento con ${labels}. ¿Quitar esas franjas solo para esta fecha y reintentar?`)) {
        this.showError(response.errors)
        return
      }
      payload.block_overlapping_ids = overlapping.map((b) => b.id)
      const retry = await this.jsonRequest(
        `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}/override`,
        "POST",
        payload
      )
      if (retry.ok) this.reloadWithToast()
      else this.showError(retry.errors)
    } else {
      this.showError(response.errors)
    }
  }

  async blockDate() {
    const id = this.blockIdTarget.value
    const date = this.occurrenceDateTarget.value
    if (!id || !date) return
    if (!confirm("¿Bloquear este horario solo en esta fecha? No se podrá reservar.")) return

    const response = await this.jsonRequest(
      `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}/override`,
      "POST",
      { date, blocked: "1", week_start: this.weekStartValue }
    )

    if (response.ok) {
      this.reloadWithToast()
    } else {
      this.showError(response.errors)
    }
  }

  async clearDateOverride() {
    const id = this.blockIdTarget.value
    const date = this.occurrenceDateTarget.value
    if (!id || !date) return

    const response = await this.jsonRequest(
      `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}/override?date=${encodeURIComponent(date)}&week_start=${encodeURIComponent(this.weekStartValue)}`,
      "DELETE",
      {}
    )

    if (response.ok) {
      this.reloadWithToast()
    } else {
      this.showError(response.errors)
    }
  }

  async destroy() {
    const id = this.blockIdTarget.value
    if (!id || !confirm("¿Eliminar esta plantilla de todos los días de la semana?")) return

    const response = await this.jsonRequest(
      `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${id}`,
      "DELETE",
      {}
    )

    if (response.ok) {
      this.reloadWithToast()
    }
  }

  async jsonRequest(url, method, body) {
    const response = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfValue,
        Accept: "application/json"
      },
      body: method === "DELETE" ? null : JSON.stringify(body)
    })

    if (response.ok) {
      return { ok: true }
    }

    const bodyText = await response.text()
    let errors = [`Error al guardar (${response.status})`]
    try {
      const data = JSON.parse(bodyText)
      if (data.errors?.length) {
        errors = data.errors
      } else if (data.error) {
        errors = [data.error]
      } else if (data.message) {
        errors = [data.message]
      }
    } catch (_e) {
      if (bodyText && bodyText.length < 280) errors = [bodyText]
    }
    return { ok: false, errors }
  }

  reloadWithToast() {
    const url = new URL(window.location.href)
    url.searchParams.set("saved", "1")
    window.location.href = url.toString()
  }

  showError(messages) {
    this.errorTarget.textContent = messages.join(", ")
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.classList.add("hidden")
  }

  dayName(day) {
    return ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"][day]
  }

  formatDateLabel(isoDate) {
    const [, m, d] = isoDate.split("-").map((v) => parseInt(v, 10))
    return `${d}/${m}`
  }

  formatCLP(cents) {
    return new Intl.NumberFormat("es-CL", {
      style: "currency",
      currency: "CLP",
      maximumFractionDigits: 0
    }).format(cents)
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
