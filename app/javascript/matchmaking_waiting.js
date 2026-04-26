const POLL_INTERVAL_MS = 2000
const STATUS_ROTATION_MS = 5000
const TRANSIENT_STATUS_MIN = 500
const STATUS_MESSAGES = [
  "Waiting for a match.",
  "Still looking for someone available.",
  "Keeping your search open.",
  "No rush. We’ll move you when someone arrives.",
  "Looking for another quiet human."
]

let matchPollInstalled = false

const installMatchmakingWaiting = () => {
  const root = document.querySelector("[data-match-waiting]")
  if (!root) return

  if (matchPollInstalled) return

  const pollUrl = root.dataset.matchPollUrl
  const statusText = root.querySelector("[data-match-status-text]")

  let intervalId = null
  let statusIntervalId = null
  let statusIndex = 0

  const stopTimers = () => {
    window.clearInterval(intervalId)
    window.clearInterval(statusIntervalId)
    matchPollInstalled = false
  }

  const rotateStatus = () => {
    if (!statusText) return

    statusIndex = (statusIndex + 1) % STATUS_MESSAGES.length
    statusText.textContent = STATUS_MESSAGES[statusIndex]
  }

  const poll = async () => {
    if (!document.body.contains(root)) {
      stopTimers()
      return
    }

    try {
      const response = await fetch(pollUrl, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (response.redirected) {
        window.location.href = response.url
        return
      }

      if (!response.ok) {
        if (response.status >= TRANSIENT_STATUS_MIN) return

        window.location.reload()
        return
      }

      const payload = await response.json()
      if (payload.status === "matched" && payload.room_url) {
        window.location.href = payload.room_url
        return
      }

      if (payload.status !== "queued") {
        window.location.reload()
        return
      }

    } catch (_error) {
      // Let the next poll try again quietly.
    }
  }

  intervalId = window.setInterval(poll, POLL_INTERVAL_MS)
  statusIntervalId = window.setInterval(rotateStatus, STATUS_ROTATION_MS)
  matchPollInstalled = true
}

export { installMatchmakingWaiting }
