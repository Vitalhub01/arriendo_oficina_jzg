import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { markers: Array }

  async connect() {
    const L = await import("leaflet")
    await this.loadLeafletCss()

    if (this.markersValue.length === 0) return

    const map = L.map(this.element)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap"
    }).addTo(map)

    const bounds = []
    this.markersValue.forEach((marker) => {
      const m = L.marker([marker.lat, marker.lng]).addTo(map)
      m.bindPopup(`<a href="${marker.url}">${marker.title}</a>`)
      bounds.push([marker.lat, marker.lng])
    })

    if (bounds.length === 1) {
      map.setView(bounds[0], 14)
    } else {
      map.fitBounds(bounds, { padding: [30, 30] })
    }
  }

  loadLeafletCss() {
    if (document.getElementById("leaflet-css")) return Promise.resolve()
    return new Promise((resolve) => {
      const link = document.createElement("link")
      link.id = "leaflet-css"
      link.rel = "stylesheet"
      link.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
      link.onload = resolve
      document.head.appendChild(link)
    })
  }
}
