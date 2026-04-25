import consumer from "channels/consumer"

const initializedRoots = new WeakSet()

const installRoomChat = () => {
  document.querySelectorAll("[data-chat-room-public-id]").forEach((root) => {
    if (initializedRoots.has(root)) return
    initializedRoots.add(root)
    initRoomChat(root)
  })
}

const initRoomChat = (root) => {
  const messagesUrl = root.dataset.chatMessagesUrl
  const roomShowUrl = root.dataset.chatRoomShowUrl
  const presenceUrl = root.dataset.chatPresenceUrl
  const list = root.querySelector("[data-chat-message-list]")
  const form = root.querySelector("[data-chat-form]")
  const bodyInput = root.querySelector("[data-chat-body]")
  const feedback = root.querySelector("[data-chat-feedback]")
  const emptyState = root.querySelector("[data-chat-empty-state]")
  const roomPill = root.querySelector("[data-chat-room-pill]")
  const roomExpirySummary = root.querySelector("[data-chat-room-expiry-summary]")
  const headerLinkChip = root.querySelector("[data-chat-header-link]")
  const headerLinkLabel = root.querySelector("[data-chat-header-link-label]")
  const headerLinkText = root.querySelector("[data-chat-header-link-text]")
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  const localParticipantId = Number(root.dataset.chatParticipantId)
  const sendButton = form?.querySelector("button")
  const retentionModeSelect = root.querySelector("[data-chat-retention-mode-select]")
  const copyButtons = root.querySelectorAll(".button-copy")
  const chatMenu = root.querySelector("[data-chat-menu]")
  const chatMenuTrigger = root.querySelector("[data-chat-menu-trigger]")
  const confirmDialog = root.querySelector("[data-chat-confirm-dialog]")
  const confirmMessage = root.querySelector("[data-chat-confirm-message]")
  const participantToken = root.dataset.chatParticipantToken
  const clientInstanceId = root.dataset.chatClientInstanceId

  if (!list || !form || !bodyInput || !sendButton || !emptyState) return

  let lastSeq = Number(root.dataset.chatLastSeq || 0)
  let expiresAt = root.dataset.chatRoomExpiresAt
  let roomOpen = root.dataset.chatOpen === "true"
  let isSending = false
  let fallbackMessagesInterval = null
  let fallbackRoomInterval = null
  let presenceInterval = null
  let expiryTimeout = null
  let pendingConfirmForm = null
  const renderedSequences = new Set(
    Array.from(list.querySelectorAll(".message-row")).map((row) => Number(row.dataset.sequenceNumber)).filter(Number.isFinite)
  )

  const scheduleExpiryTimeout = () => {
    if (expiryTimeout) window.clearTimeout(expiryTimeout)
    if (!expiresAt) return

    const delay = new Date(expiresAt).getTime() - Date.now()
    if (delay <= 0) {
      updateComposerState("expired", "Expired", expiresAt)
      return
    }

    expiryTimeout = window.setTimeout(() => {
      updateComposerState("expired", "Expired", expiresAt)
    }, delay + 50)
  }

  const setFeedback = (message, isError = false) => {
    if (!feedback) return
    feedback.textContent = message
    feedback.classList.toggle("is-error", isError)
    feedback.classList.toggle("is-hidden", !message)
  }

  const appendMessage = (message) => {
    const sequenceNumber = Number(message.sequence_number)
    if (renderedSequences.has(sequenceNumber)) return

    const item = document.createElement("li")
    const senderId = Number(message.sender.id)
    item.className = `message-row ${senderId === localParticipantId ? "message-row-local" : "message-row-remote"}`
    item.dataset.sequenceNumber = sequenceNumber

    const shell = document.createElement("div")
    shell.className = "message-shell"

    const meta = document.createElement("span")
    meta.className = "message-meta"

    const strong = document.createElement("strong")
    strong.textContent = message.sender.nickname

    const time = document.createElement("time")
    const createdAt = new Date(message.created_at)
    time.dateTime = message.created_at
    time.textContent = createdAt.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })

    const body = document.createElement("span")
    body.className = "message-body"
    body.textContent = message.body

    meta.append(strong, time)
    shell.append(meta, body)
    item.append(shell)
    list.append(item)
    list.scrollTop = list.scrollHeight
    emptyState.classList.add("is-hidden")
    renderedSequences.add(sequenceNumber)
    lastSeq = Math.max(lastSeq, sequenceNumber)
  }

  const updateComposerState = (status, expirySummary = null, nextExpiresAt = null) => {
    roomPill.textContent = status.replace("_", " ")
    roomOpen = !["ended", "expired"].includes(status)
    bodyInput.disabled = !roomOpen
    sendButton.disabled = !roomOpen || isSending
    if (roomExpirySummary && expirySummary) roomExpirySummary.textContent = expirySummary
    if (nextExpiresAt) expiresAt = nextExpiresAt
    updateHeaderLink(status)
    scheduleExpiryTimeout()

    if (!roomOpen) {
      setFeedback("This room is closed for new messages.", false)
    } else {
      setFeedback("", false)
    }
  }

  const updateHeaderLink = (status) => {
    if (!headerLinkChip || !headerLinkText || !headerLinkLabel) return

    const bookmarkUrl = headerLinkChip.dataset.bookmarkUrl
    const shareUrl = headerLinkChip.dataset.shareUrl
    const shouldShowShare = status === "waiting" && shareUrl && root.dataset.chatRole === "creator"
    const nextUrl = shouldShowShare ? shareUrl : bookmarkUrl
    const nextLabel = shouldShowShare ? headerLinkChip.dataset.waitingLabel : headerLinkChip.dataset.activeLabel

    if (!nextUrl) {
      headerLinkChip.classList.add("is-hidden")
      return
    }

    headerLinkChip.classList.remove("is-hidden")
    headerLinkChip.dataset.copyValue = nextUrl
    headerLinkText.value = nextUrl
    headerLinkText.setAttribute("aria-label", nextLabel)
    headerLinkLabel.textContent = nextLabel
  }

  const autosizeComposer = () => {
    const maxHeight = 140
    const compactHeight = 52
    bodyInput.style.height = "0px"
    bodyInput.style.height = `${Math.min(bodyInput.scrollHeight, maxHeight)}px`
    bodyInput.classList.toggle("is-scrollable", bodyInput.scrollHeight > compactHeight)
  }

  const syncRetentionFields = () => {
    if (!retentionModeSelect) return

    root.querySelectorAll("[data-retention-detail]").forEach((element) => {
      element.hidden = element.dataset.retentionDetail !== retentionModeSelect.value
    })
  }

  const syncMessages = async () => {
    try {
      const response = await fetch(`${messagesUrl}?after_seq=${lastSeq}`, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) return
      const payload = await response.json()
      ;(payload.messages || []).forEach(appendMessage)
    } catch (_) {
    }
  }

  const syncRoomState = async () => {
    try {
      const response = await fetch(roomShowUrl, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) return
      const payload = await response.json()
      if (payload.room?.status) updateComposerState(payload.room.status, payload.room.expiry_summary, payload.room.expires_at)
    } catch (_) {
    }
  }

  const pingPresence = async () => {
    if (!presenceUrl || !participantToken || !roomOpen) return

    try {
      await fetch(presenceUrl, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": csrfToken
        },
        credentials: "same-origin"
      })
    } catch (_) {
    }
  }

  const startFallbackSync = () => {
    if (!fallbackMessagesInterval) {
      fallbackMessagesInterval = window.setInterval(syncMessages, 15000)
    }
    if (!fallbackRoomInterval) {
      fallbackRoomInterval = window.setInterval(syncRoomState, 30000)
    }
  }

  const startPresenceHeartbeat = () => {
    if (presenceInterval) return

    pingPresence()
    presenceInterval = window.setInterval(pingPresence, 30000)
  }

  const stopPresenceHeartbeat = () => {
    if (!presenceInterval) return

    window.clearInterval(presenceInterval)
    presenceInterval = null
  }

  const stopFallbackSync = () => {
    if (fallbackMessagesInterval) {
      window.clearInterval(fallbackMessagesInterval)
      fallbackMessagesInterval = null
    }
    if (fallbackRoomInterval) {
      window.clearInterval(fallbackRoomInterval)
      fallbackRoomInterval = null
    }
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault()

    const body = bodyInput.value.trim()
    if (!body || !roomOpen || isSending) return

    isSending = true
    sendButton.disabled = true

    try {
      const response = await fetch(messagesUrl, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        credentials: "same-origin",
        body: JSON.stringify({ body })
      })

      const payload = await response.json()

      if (!response.ok) {
        setFeedback(payload.error || "Message failed to send.", true)
        return
      }

      appendMessage(payload.message)
      if (payload.room?.status) updateComposerState(payload.room.status, payload.room.expiry_summary, payload.room.expires_at)
      bodyInput.value = ""
      autosizeComposer()
      setFeedback("", false)
    } catch (_) {
      setFeedback("Network error while sending.", true)
    } finally {
      isSending = false
      sendButton.disabled = !roomOpen
    }
  })

  bodyInput.addEventListener("input", autosizeComposer)
  bodyInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      form.requestSubmit()
    }
  })
  retentionModeSelect?.addEventListener("change", syncRetentionFields)

  if (chatMenu && chatMenuTrigger) {
    chatMenuTrigger.setAttribute("aria-expanded", String(chatMenu.open))
    chatMenu.addEventListener("toggle", () => {
      chatMenuTrigger.setAttribute("aria-expanded", String(chatMenu.open))
    })
  }

  document.addEventListener("click", (event) => {
    if (!chatMenu?.open) return
    if (chatMenu.contains(event.target)) return

    chatMenu.open = false
  })

  copyButtons.forEach((button) => {
    button.addEventListener("click", async () => {
      const chip = button.closest("[data-copy-value]")
      const value = chip?.dataset.copyValue
      if (!value) return

      try {
        await navigator.clipboard.writeText(value)
        const originalText = button.textContent
        button.textContent = "Copied"
        window.setTimeout(() => {
          button.textContent = originalText
        }, 1200)
      } catch (_) {
        button.textContent = "Copy failed"
      }
    })
  })

  root.querySelectorAll("form[data-chat-confirm]").forEach((actionForm) => {
    actionForm.addEventListener("submit", (event) => {
      if (actionForm.dataset.chatConfirmed === "true") {
        delete actionForm.dataset.chatConfirmed
        return
      }

      const message = actionForm.dataset.chatConfirm
      if (!message || !confirmDialog || !confirmMessage) return

      event.preventDefault()
      pendingConfirmForm = actionForm
      confirmMessage.textContent = message
      confirmDialog.showModal()
    })
  })

  confirmDialog?.addEventListener("close", () => {
    if (confirmDialog.returnValue !== "confirm" || !pendingConfirmForm) {
      pendingConfirmForm = null
      return
    }

    pendingConfirmForm.dataset.chatConfirmed = "true"
    pendingConfirmForm.requestSubmit()
    pendingConfirmForm = null
  })

  headerLinkText?.addEventListener("focus", () => headerLinkText.select())
  headerLinkText?.addEventListener("click", () => headerLinkText.select())

  list.scrollTop = list.scrollHeight
  autosizeComposer()
  syncRetentionFields()
  updateComposerState(root.dataset.chatRoomStatus, roomExpirySummary?.textContent, expiresAt)

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
      syncMessages()
      syncRoomState()
      pingPresence()
    }
  })

  if (participantToken) {
    consumer.subscriptions.create(
      {
        channel: "RoomChannel",
        room_public_id: root.dataset.chatRoomPublicId,
        participant_token: participantToken,
        client_instance_id: clientInstanceId
      },
      {
        connected() {
          stopFallbackSync()
          startPresenceHeartbeat()
          syncMessages()
          syncRoomState()
        },

        disconnected() {
          startFallbackSync()
          stopPresenceHeartbeat()
        },

        rejected() {
          startFallbackSync()
          stopPresenceHeartbeat()
          setFeedback("This bookmark is already active in another browser.", true)
        },

        received(data) {
          if (data.type === "message.created" && data.message) {
            if (Number(data.message.sequence_number) > lastSeq) appendMessage(data.message)
            if (data.room?.status) updateComposerState(data.room.status, data.room.expiry_summary, data.room.expires_at)
          }

          if (data.type === "room.updated" && data.room) {
            updateComposerState(data.room.status, data.room.expiry_summary, data.room.expires_at)
          }
        }
      }
    )
  } else {
    startFallbackSync()
  }
}

export { installRoomChat }
