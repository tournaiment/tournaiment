import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    iso: String
  }

  connect() {
    if (!this.hasIsoValue) return

    const date = new Date(this.isoValue)
    if (Number.isNaN(date.getTime())) return

    this.element.textContent = this.formatSimple(date)
    this.element.setAttribute("title", this.formatDetailed(date))
  }

  formatSimple(date) {
    const datePart = new Intl.DateTimeFormat(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric"
    }).format(date)
    const timePart = new Intl.DateTimeFormat(undefined, {
      hour: "numeric",
      minute: "2-digit"
    }).format(date)

    return `${datePart} ${timePart}`
  }

  formatDetailed(date) {
    return new Intl.DateTimeFormat(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "short"
    }).format(date)
  }
}
