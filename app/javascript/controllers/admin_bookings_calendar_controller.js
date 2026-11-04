import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toast", "pageError"]
  static values = {
    spaceId: Number,
    weekStart: String,
    csrf: String
  }

  async blockSlot(event) {
    event.preventDefault()
    event.stopPropagation()

    const { blockId, date } = event.currentTarget.dataset
    if (!blockId || !date) return
    if (!confirm("¿Bloquear este horario solo en esta fecha? No se podrá reservar.")) return

    const response = await this.jsonRequest(
      `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${blockId}/override`,
      "POST",
      { date, blocked: "1", week_start: this.weekStartValue }
    )

    if (response.ok) {
      this.reloadWithToast()
    } else {
      this.showError(response.errors)
    }
  }

  async unblockSlot(event) {
    event.preventDefault()
    event.stopPropagation()

    const el = event.currentTarget
    const date = el.dataset.date
    const blockIds = (el.dataset.blockIds || el.dataset.blockId || "")
      .split(",")
      .map((id) => id.trim())
      .filter(Boolean)

    if (!date || blockIds.length === 0) return
    if (!confirm("¿Quitar el bloqueo y restaurar la plantilla para este día?")) return

    for (const blockId of blockIds) {
      const url =
        `/admin/spaces/${this.spaceIdValue}/schedule_blocks/${blockId}/override` +
        `?date=${encodeURIComponent(date)}&week_start=${encodeURIComponent(this.weekStartValue)}`

      const response = await this.jsonDelete(url)
      if (!response.ok) {
        this.showError(response.errors)
        return
      }
    }

    this.reloadWithToast()
  }

  async cancelBooking(event) {
    event.preventDefault()
    event.stopPropagation()

    const ids = (event.currentTarget.dataset.bookingIds || "")
      .split(",")
      .map((id) => id.trim())
      .filter(Boolean)

    if (ids.length === 0) return

    const message =
      ids.length === 1
        ? "¿Anular esta reserva?"
        : `¿Anular las ${ids.length} reservas en esta franja?`

    if (!confirm(message)) return

    for (const id of ids) {
      const response = await this.jsonRequest(
        `/admin/bookings/${id}`,
        "PATCH",
        { cancel: true }
      )

      if (!response.ok) {
        this.showError(response.errors)
        return
      }
    }

    this.reloadWithToast()
  }

  async restoreBooking(event) {
    event.preventDefault()
    event.stopPropagation()

    const ids = (event.currentTarget.dataset.bookingIds || "")
      .split(",")
      .map((id) => id.trim())
      .filter(Boolean)

    if (ids.length === 0) return

    const message =
      ids.length === 1
        ? "¿Reactivar esta reserva anulada?"
        : `¿Reactivar las ${ids.length} reservas anuladas en esta franja?`

    if (!confirm(message)) return

    for (const id of ids) {
      const response = await this.jsonRequest(
        `/admin/bookings/${id}`,
        "PATCH",
        { restore: true }
      )

      if (!response.ok) {
        this.showError(response.errors)
        return
      }
    }

    this.reloadWithToast()
  }

  async dismissFromCalendar(event) {
    event.preventDefault()
    event.stopPropagation()

    const ids = (event.currentTarget.dataset.bookingIds || "")
      .split(",")
      .map((id) => id.trim())
      .filter(Boolean)

    if (ids.length === 0) return

    const message =
      ids.length === 1
        ? "¿Marcar este horario como disponible en el calendario? La reserva sigue anulada en el historial."
        : `¿Marcar estos ${ids.length} horarios como disponibles en el calendario? Las reservas siguen anuladas.`

    if (!confirm(message)) return

    for (const id of ids) {
      const response = await this.jsonRequest(
        `/admin/bookings/${id}`,
        "PATCH",
        { dismiss_from_calendar: true }
      )

      if (!response.ok) {
        this.showError(response.errors)
        return
      }
    }

    this.reloadWithToast()
  }

  openBooking(event) {
    if (event.target.closest("[data-slot-action]")) return

    const url = event.currentTarget.dataset.bookingUrl
    if (url) window.location.href = url
  }

  async jsonRequest(url, method, body) {
    const response = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfValue,
        Accept: "application/json"
      },
      body: JSON.stringify(body)
    })

    return this.parseResponse(response)
  }

  async jsonDelete(url) {
    const response = await fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": this.csrfValue,
        Accept: "application/json"
      }
    })

    return this.parseResponse(response)
  }

  async parseResponse(response) {
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
    const text = messages.join(", ")
    if (this.hasPageErrorTarget) {
      this.pageErrorTarget.textContent = text
      this.pageErrorTarget.classList.remove("hidden")
    }
  }
}
