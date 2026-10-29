import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "panel", "image", "caption", "prevButton", "nextButton"]
  static values = { photos: Array }

  connect() {
    this.index = 0
    this.boundBackdropClose = (event) => {
      if (event.target === this.dialogTarget) this.close()
    }
    this.boundPanelClick = (event) => {
      event.stopPropagation()
    }
    this.boundDialogClose = () => this.onDialogClosed()
    this.dialogTarget.addEventListener("click", this.boundBackdropClose)
    this.dialogTarget.addEventListener("close", this.boundDialogClose)
    if (this.hasPanelTarget) {
      this.panelTarget.addEventListener("click", this.boundPanelClick)
    }
  }

  disconnect() {
    this.dialogTarget.removeEventListener("click", this.boundBackdropClose)
    this.dialogTarget.removeEventListener("close", this.boundDialogClose)
    if (this.hasPanelTarget) {
      this.panelTarget.removeEventListener("click", this.boundPanelClick)
    }
    document.body.classList.remove("overflow-hidden")
  }

  open(event) {
    const index = event.params.index
    if (index == null || Number.isNaN(Number(index))) return

    this.show(Number(index))
  }

  show(index) {
    const photo = this.photosValue[index]
    if (!photo) return

    this.index = index
    this.imageTarget.src = photo.url
    this.imageTarget.alt = photo.alt || ""
    if (this.hasCaptionTarget) {
      const text = photo.alt || ""
      this.captionTarget.textContent = text
      this.captionTarget.classList.toggle("hidden", text.length === 0)
    }

    const multiple = this.photosValue.length > 1
    if (this.hasPrevButtonTarget) this.prevButtonTarget.classList.toggle("hidden", !multiple)
    if (this.hasNextButtonTarget) this.nextButtonTarget.classList.toggle("hidden", !multiple)

    this.dialogTarget.showModal()
    document.body.classList.add("overflow-hidden")
  }

  close() {
    if (!this.dialogTarget.open) return

    this.dialogTarget.close()
  }

  onDialogClosed() {
    document.body.classList.remove("overflow-hidden")
    if (this.hasImageTarget) this.imageTarget.removeAttribute("src")
  }

  prev() {
    if (this.photosValue.length < 2) return

    const index = (this.index - 1 + this.photosValue.length) % this.photosValue.length
    this.show(index)
  }

  next() {
    if (this.photosValue.length < 2) return

    const index = (this.index + 1) % this.photosValue.length
    this.show(index)
  }

  handleKey(event) {
    if (!this.dialogTarget.open) return
    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    }
  }
}
