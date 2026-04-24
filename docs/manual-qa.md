# Manual QA Checklist

Use one normal browser window and one incognito/private window for the two participants.

## Core flow

- Create a room from the homepage
- Confirm the creator lands in the room and sees:
  - status pill
  - hamburger menu
  - share link
  - bookmark link
- Open the invite link in the incognito/private window
- Confirm the guest sees the invite interstitial first
- Click `Join chat`
- Confirm both sides become active

## Realtime

- Send a message from the creator and confirm it appears once on both sides
- Send a message from the guest and confirm it appears once on both sides
- Reload one side and confirm recent messages restore correctly

## Retention

- As creator, set retention to `Last 10 messages`
- Send more than 10 messages
- Reload both sides and confirm only the latest 10 remain
- Switch retention to `For 1 hour`
- Confirm the guest sees the summary, not the editor
- Run `bin/rails hushpair:maintenance` locally and confirm old messages outside the window are removed

## Room lifecycle

- Confirm a waiting room expires if the second participant never joins
- Confirm an active room shows a lifetime summary
- Send a message and confirm the room lifetime extends
- Click `Leave chat` from one side:
  - user returns to home
  - bookmark link still works until expiry
- Click `End chat` from one side:
  - both participants see the room close
  - new messages are blocked
  - bookmark links no longer restore access

## Invite and bookmark safety

- Open the invite link in the creator’s own browser and confirm it does not create a fake second participant
- Confirm the invite interstitial does not join the room on GET alone
- Confirm the bookmark link restores only the original participant while the room is active
- Confirm an expired room no longer restores from the bookmark link

## Theme and accessibility

- Toggle light and dark mode
- Confirm contrast remains readable in:
  - header
  - menu
  - transcript
  - composer
- Tab through the page and confirm visible focus styles
- Open the hamburger menu with keyboard navigation
- Hover and keyboard-focus the `?` help tips

## Browser matrix

Check at least:

- Chrome
- Safari
- Firefox
- iPhone Safari
- Android Chrome

Focus on:

- websocket connection stability
- textarea growth behavior
- menu open/close behavior
- dark mode persistence
- copy-link buttons

## Production smoke

After deploying:

- verify `https://hushpair.com/up`
- verify websocket upgrade through `/cable`
- create a real room over HTTPS
- send messages between two devices on different networks
- run `hushpair:maintenance` once and confirm no plaintext content appears in logs
