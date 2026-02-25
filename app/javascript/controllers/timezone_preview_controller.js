import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeZone", "startsInput", "endsInput", "startsPreview", "endsPreview"]

  connect() {
    this.refresh()
  }

  refresh() {
    const timeZone = this.hasTimeZoneTarget ? this.timeZoneTarget.value : "UTC"
    this.updatePreview(this.startsInputTarget.value, this.startsPreviewTarget, timeZone)
    this.updatePreview(this.endsInputTarget.value, this.endsPreviewTarget, timeZone)
  }

  updatePreview(raw, previewTarget, timeZone) {
    if (!raw) {
      previewTarget.textContent = "Stored as UTC: -"
      return
    }

    const parsed = this.parseLocalDateTime(raw)
    if (!parsed) {
      previewTarget.textContent = "Stored as UTC: Invalid datetime"
      return
    }

    const utcDate = this.zonedTimeToUtc(parsed, timeZone)
    if (!utcDate) {
      previewTarget.textContent = "Stored as UTC: Invalid timezone"
      return
    }

    previewTarget.textContent = `Stored as UTC: ${this.formatUtc(utcDate)}`
  }

  parseLocalDateTime(raw) {
    const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/)
    if (!match) return null

    return {
      year: parseInt(match[1], 10),
      month: parseInt(match[2], 10),
      day: parseInt(match[3], 10),
      hour: parseInt(match[4], 10),
      minute: parseInt(match[5], 10)
    }
  }

  zonedTimeToUtc(parts, timeZone) {
    const utcGuess = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, 0)
    const firstOffset = this.offsetForTimeZone(new Date(utcGuess), timeZone)
    if (firstOffset === null) return null

    let corrected = utcGuess - firstOffset
    const secondOffset = this.offsetForTimeZone(new Date(corrected), timeZone)
    if (secondOffset === null) return null
    if (secondOffset !== firstOffset) corrected = utcGuess - secondOffset

    return new Date(corrected)
  }

  offsetForTimeZone(date, timeZone) {
    try {
      const formatter = new Intl.DateTimeFormat("en-CA", {
        timeZone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false
      })

      const parts = formatter.formatToParts(date).reduce((acc, part) => {
        if (part.type !== "literal") acc[part.type] = part.value
        return acc
      }, {})

      const asUtc = Date.UTC(
        parseInt(parts.year, 10),
        parseInt(parts.month, 10) - 1,
        parseInt(parts.day, 10),
        parseInt(parts.hour, 10),
        parseInt(parts.minute, 10),
        parseInt(parts.second, 10)
      )

      return asUtc - date.getTime()
    } catch (_error) {
      return null
    }
  }

  formatUtc(date) {
    return `${date.toISOString().slice(0, 16).replace("T", " ")} UTC`
  }
}
