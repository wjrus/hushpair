// Importmap entrypoint for lightweight client-side behavior.
import { installMatchmakingWaiting } from "matchmaking_waiting"
import { installRoomChat } from "room_chat"

const THEME_STORAGE_KEY = "hushpair-theme"

const applyTheme = (theme) => {
  document.documentElement.dataset.theme = theme

  const toggle = document.querySelector("[data-theme-toggle]")
  if (!toggle) return

  const isDark = theme === "dark"
  const thumb = toggle.querySelector(".theme-toggle__thumb")
  toggle.setAttribute("aria-pressed", String(isDark))
  toggle.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode")
  if (thumb) thumb.textContent = isDark ? "☾" : "☀"
}

const preferredTheme = () => {
  const storedTheme = window.localStorage.getItem(THEME_STORAGE_KEY)
  if (storedTheme === "light" || storedTheme === "dark") return storedTheme

  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
}

let themeToggleInstalled = false
let flashDismissInstalled = false

const installThemeToggle = () => {
  applyTheme(preferredTheme())

  if (themeToggleInstalled) return

  document.querySelector("[data-theme-toggle]")?.addEventListener("click", () => {
    const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    window.localStorage.setItem(THEME_STORAGE_KEY, nextTheme)
    applyTheme(nextTheme)
  })

  themeToggleInstalled = true
}

const installFlashDismiss = () => {
  if (flashDismissInstalled) return

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-flash-dismiss]")
    if (!button) return

    button.closest("[data-flash]")?.remove()
  })

  flashDismissInstalled = true
}

const installAppUi = () => {
  installThemeToggle()
  installFlashDismiss()
  installMatchmakingWaiting()
  installRoomChat()
}

document.addEventListener("turbo:load", installAppUi)
document.addEventListener("DOMContentLoaded", installAppUi)
