import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const loginTab = this.tabTargets.find((t) => t.dataset.tab === "login")
    if (loginTab) this.activateTab("login")
  }

  showTab(event) {
    const tabName = event.currentTarget.dataset.tab
    this.activateTab(tabName)
  }

  activateTab(tabName) {

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tab === tabName
      tab.classList.toggle("border-brand", active)
      tab.classList.toggle("text-brand", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-gray-500", !active)
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tab !== tabName)
    })
  }
}
