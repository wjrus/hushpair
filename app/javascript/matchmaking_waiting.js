const POLL_INTERVAL_MS = 2000
const STATUS_ROTATION_MS = 5000
const TRANSIENT_STATUS_MIN = 500
const BACKGROUND_MATCH_REDIRECT_DELAY_MS = 700
const STATUS_MESSAGES = [
  "Waiting for a match.",
  "Still looking for someone available.",
  "Keeping your search open.",
  "No rush. We’ll move you when someone arrives.",
  "Looking for another quiet human."
]

let matchPollInstalled = false
let notificationAudioContext = null

const ensureNotificationAudioContext = () => {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext
  if (!AudioContextClass) return null

  notificationAudioContext ||= new AudioContextClass()
  return notificationAudioContext
}

const unlockNotificationAudio = () => {
  ensureNotificationAudioContext()?.resume?.().catch(() => {})
}

const playBackgroundMatchCue = () => {
  if (document.visibilityState !== "hidden") return false

  const audioContext = ensureNotificationAudioContext()
  if (!audioContext) return false

  audioContext.resume?.().catch(() => {})

  const startAt = audioContext.currentTime + 0.02
  const tones = [
    { frequency: 740, offset: 0, duration: 0.13 },
    { frequency: 440, offset: 0.16, duration: 0.18 }
  ]

  tones.forEach(({ frequency, offset, duration }) => {
    const oscillator = audioContext.createOscillator()
    const gain = audioContext.createGain()
    const toneStart = startAt + offset
    const toneEnd = toneStart + duration

    oscillator.type = "sine"
    oscillator.frequency.setValueAtTime(frequency, toneStart)
    gain.gain.setValueAtTime(0.0001, toneStart)
    gain.gain.exponentialRampToValueAtTime(0.08, toneStart + 0.015)
    gain.gain.exponentialRampToValueAtTime(0.0001, toneEnd)

    oscillator.connect(gain).connect(audioContext.destination)
    oscillator.start(toneStart)
    oscillator.stop(toneEnd + 0.02)
  })

  return true
}

const installMatchmakingWaiting = () => {
  const root = document.querySelector("[data-match-waiting]")
  if (!root) return

  if (matchPollInstalled) return

  const pollUrl = root.dataset.matchPollUrl
  const statusText = root.querySelector("[data-match-status-text]")

  let intervalId = null
  let statusIntervalId = null
  let statusIndex = 0

  document.addEventListener("pointerdown", unlockNotificationAudio, { once: true })
  document.addEventListener("keydown", unlockNotificationAudio, { once: true })

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
        stopTimers()
        const didPlayCue = playBackgroundMatchCue()
        window.setTimeout(() => {
          window.location.href = payload.room_url
        }, didPlayCue ? BACKGROUND_MATCH_REDIRECT_DELAY_MS : 0)
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
