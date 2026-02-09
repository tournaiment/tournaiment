import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.closeOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("user-menu--open")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.remove("user-menu--open")
    }
  }
}
