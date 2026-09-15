import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "all", "submit"]

  connect() {
    this.update()
  }

  toggleAll() {
    this.itemTargets.forEach((item) => { item.checked = this.allTarget.checked })
    this.update()
  }

  update() {
    const selected = this.itemTargets.filter((item) => item.checked).length
    this.submitTargets.forEach((button) => { button.disabled = selected === 0 })

    if (this.hasAllTarget) {
      this.allTarget.checked = selected > 0 && selected === this.itemTargets.length
      this.allTarget.indeterminate = selected > 0 && selected < this.itemTargets.length
    }
  }
}
