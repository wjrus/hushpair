// Importmap entrypoint for lightweight client-side behavior.
import { installMatchmakingWaiting } from "matchmaking_waiting"
import { installRoomChat } from "room_chat"

const THEME_STORAGE_KEY = "hushpair-theme"
const THEME_CHOICES = new Set(["system", "light", "dark", "terminal", "amber", "paper"])

const systemTheme = () => {
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
}

const savedThemeChoice = () => {
  const storedTheme = window.localStorage.getItem(THEME_STORAGE_KEY)
  if (THEME_CHOICES.has(storedTheme)) return storedTheme

  return "system"
}

const applyThemeChoice = (choice) => {
  const resolvedTheme = choice === "system" ? systemTheme() : choice
  document.documentElement.dataset.theme = resolvedTheme
  document.documentElement.dataset.themeChoice = choice

  document.querySelectorAll("[data-theme-select]").forEach((select) => {
    select.value = choice
  })
}

let themeToggleInstalled = false
let flashDismissInstalled = false

const installThemeToggle = () => {
  applyThemeChoice(savedThemeChoice())

  if (themeToggleInstalled) return

  document.addEventListener("change", (event) => {
    const select = event.target.closest("[data-theme-select]")
    if (!select) return

    const choice = THEME_CHOICES.has(select.value) ? select.value : "system"
    window.localStorage.setItem(THEME_STORAGE_KEY, choice)
    applyThemeChoice(choice)
  })

  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    if (savedThemeChoice() === "system") applyThemeChoice("system")
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
