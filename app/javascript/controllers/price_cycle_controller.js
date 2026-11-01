import { Controller } from "@hotwired/stimulus"

let sharedPeriodIndex = 0
let sharedTimerId = null
const activeControllers = new Set()

function sharedReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

function stopSharedTimer() {
  if (sharedTimerId) {
    window.clearInterval(sharedTimerId)
    sharedTimerId = null
  }
}

function startSharedTimer(intervalMs) {
  stopSharedTimer()
  if (sharedReducedMotion() || activeControllers.size === 0) return

  sharedTimerId = window.setInterval(() => {
    const lengths = [...activeControllers].map((c) => c.itemsValue.length)
    const cycleLength = Math.max(...lengths, 1)
    sharedPeriodIndex = (sharedPeriodIndex + 1) % cycleLength
    syncAllControllers({ animate: true, animateAmount: true })
  }, intervalMs)
}

function syncAllControllers({ animate, animateAmount }) {
  activeControllers.forEach((controller) => {
    controller.applySharedIndex({ animate, animateAmount })
  })
}

export default class extends Controller {
  static targets = ["amount", "track", "indicator", "option"]
  static values = {
    items: { type: Array, default: [] },
    interval: { type: Number, default: 3500 }
  }

  connect() {
    if (this.itemsValue.length < 2) return

    this.reducedMotion = sharedReducedMotion()
    activeControllers.add(this)
    this.applySharedIndex({ animate: false, animateAmount: false })

    this.resizeObserver = new ResizeObserver(() => this.syncIndicator(false))
    this.resizeObserver.observe(this.trackTarget)

    if (!sharedTimerId && !this.reducedMotion) {
      startSharedTimer(this.intervalValue)
    }
  }

  disconnect() {
    activeControllers.delete(this)
    this.resizeObserver?.disconnect()
    if (activeControllers.size === 0) {
      stopSharedTimer()
      sharedPeriodIndex = 0
    }
  }

  select({ params: { index } }) {
    const next = Number(index)
    if (Number.isNaN(next) || next < 0 || next >= this.itemsValue.length) return

    sharedPeriodIndex = next
    syncAllControllers({ animate: true, animateAmount: true })
    startSharedTimer(this.intervalValue)
  }

  applySharedIndex({ animate, animateAmount }) {
    const next = Math.min(sharedPeriodIndex, this.itemsValue.length - 1)
    this.index = next
    requestAnimationFrame(() => {
      this.syncIndicator(animate)
      this.updateAmount(animateAmount)
    })
  }

  syncIndicator(animate) {
    const option = this.optionTargets[this.index]
    if (!option || !this.hasIndicatorTarget) return

    const left = option.offsetLeft
    const top = option.offsetTop
    const width = option.offsetWidth
    const height = option.offsetHeight

    const indicator = this.indicatorTarget
    indicator.style.width = `${width}px`
    indicator.style.height = `${height}px`
    indicator.style.transform = `translate(${left}px, ${top}px)`

    if (!animate) {
      indicator.style.transitionDuration = "0ms"
      indicator.offsetHeight
      indicator.style.transitionDuration = ""
    }

    this.optionTargets.forEach((el, i) => {
      const active = i === this.index
      el.classList.toggle("text-white", active)
      el.classList.toggle("text-gray-600", !active)
      el.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  updateAmount(animate) {
    const item = this.itemsValue[this.index]
    if (!item || !this.hasAmountTarget) return

    if (!animate || this.reducedMotion) {
      this.amountTarget.textContent = item.amount
      return
    }

    this.amountTarget.classList.add("opacity-0", "translate-y-0.5")
    window.setTimeout(() => {
      this.amountTarget.textContent = item.amount
      this.amountTarget.classList.remove("opacity-0", "translate-y-0.5")
    }, 180)
  }
}
