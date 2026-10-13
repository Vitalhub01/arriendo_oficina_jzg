import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { lat: Number, lng: Number, address: String }

  async connect() {
    const { default: L } = await import("leaflet")
    this.configureLeafletIcons(L)
    await this.loadLeafletCss()

    if (!this.element.dataset.initialized) {
      const map = L.map(this.element).setView([this.latValue, this.lngValue], 15)
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
      }).addTo(map)
      L.marker([this.latValue, this.lngValue]).addTo(map)
        .bindPopup(this.addressValue)
        .openPopup()
      this.element.dataset.initialized = "true"
    }
  }

  configureLeafletIcons(L) {
    delete L.Icon.Default.prototype._getIconUrl
    L.Icon.Default.mergeOptions({
      iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
      iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
      shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png"
    })
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
