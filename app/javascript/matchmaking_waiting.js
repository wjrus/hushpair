const POLL_INTERVAL_MS = 2000

let matchPollInstalled = false

const installMatchmakingWaiting = () => {
  const root = document.querySelector("[data-match-waiting]")
  if (!root) return

  if (matchPollInstalled) return

  const pollUrl = root.dataset.matchPollUrl
  const queueSize = root.querySelector("[data-match-queue-size]")

  let intervalId = null

  const poll = async () => {
    if (!document.body.contains(root)) {
      window.clearInterval(intervalId)
      matchPollInstalled = false
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
        window.location.reload()
        return
      }

      const payload = await response.json()
      if (payload.status !== "queued") {
        window.location.reload()
        return
      }

      if (queueSize && typeof payload.queue_size === "number") {
        const suffix = payload.queue_size === 1 ? "person waiting" : "people waiting"
        queueSize.textContent = `${payload.queue_size} ${suffix}`
      }
    } catch (_error) {
      // Let the next poll try again quietly.
    }
  }

  intervalId = window.setInterval(poll, POLL_INTERVAL_MS)
  matchPollInstalled = true
}

export { installMatchmakingWaiting }
