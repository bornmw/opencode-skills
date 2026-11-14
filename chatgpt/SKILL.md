---
name: chatgpt
description: |
  Ask ChatGPT (chatgpt.com) for an answer through a Marionette-driven Firefox,
  using the firefox-mcp-marionette MCP (https://github.com/bornmw/firefox-mcp-marionette),
  a required dependency (fx_* tools). Load when the user asks to
  "ask ChatGPT", "send a prompt to ChatGPT", "get a ChatGPT answer / second
  opinion", "check this with ChatGPT", "run this prompt through ChatGPT", or to
  use chatgpt.com and return its reply. Do NOT load for generic browser tasks,
  other sites, or when the answer can be given without ChatGPT.
---

# ChatGPT via Marionette

Ask chatgpt.com a prompt and return the **finished** answer, driving a real
Firefox (the user's profile, the user's login) through the
`firefox-mcp-marionette` MCP (`fx_*` tools).

All selectors below were verified live on **2026-11-14** against the current
chatgpt.com UI. Hashed CSS-module classes (`Name-<hash>`) change on every
deploy — always match by **substring** (`[class*="Name"]`), never by full
class name.

## Prerequisites

- **Dependency:** the [firefox-mcp-marionette](https://github.com/bornmw/firefox-mcp-marionette)
  MCP server registered in opencode (the `fx_*` tools are available). Without
  it this skill cannot run.
- A Firefox with an active ChatGPT login (a dedicated profile is recommended).

## 1. Bootstrap the browser

1. Call `fx_status`.
2. Act on the result:
   - `connected: true` → proceed.
   - `nothing-listening` / `browser-detected` / `busy-other-client` → the tool
     returns a decision payload with options. **Present the options to the
     user and use their choice** (`fx_connect {host, port}` / `fx_launch` /
     their direction). Never attach to a detected browser or launch on your
     own judgment.
3. Note: an instance started by `fx_launch` has a **fresh profile** — no
   cookies, no logins. It will fail the login check below; that is expected
   and the fix is to ask the user to log in (step 2).

## 2. Login check (always run, before anything else)

1. `fx_navigate {url: "https://chatgpt.com/"}`.
2. Read the state via `fx_eval`:

   ```js
   (function() {
     var logIn = [].slice.call(document.querySelectorAll('button, a'))
       .filter(function(e) { return /log in/i.test(e.innerText) && e.offsetParent !== null; });
     var composer = [].slice.call(document.querySelectorAll('div[contenteditable="true"]'))
       .filter(function(d) { return d.offsetParent !== null && d.getBoundingClientRect().width > 0; });
     return { loggedIn: composer.length > 0 && logIn.length === 0,
              url: location.href, title: document.title };
   })()
   ```

   - **Logged in**: a visible composer exists, no visible "Log in" button,
     app-shell sidebar with "New chat".
   - **Logged out**: visible "Log in" button(s), a hidden
     `input[name="login_hint"]`, marketing title
     "ChatGPT: Chat, Work, Create & Code with AI".
   - **Settling**: right after `fx_navigate`, the welcome composer can take a
     moment to render — you may read *neither* state (no composer, no Log-in
     button, app title). If so, sleep 2 s in-page and re-evaluate, up to ~10
     times, before classifying. Never treat "no composer yet" as logged out.
3. **If not logged in: stop and ask the user to log in.** Say: the browser is
   not logged into ChatGPT — please log in in the open browser window
   (email / 2FA / CAPTCHA are human steps by design). Then poll the check
   above every ~5 s (in-page sleep: `fx_eval` with
   `new Promise(function(r){ setTimeout(r, 5000); })`) until `loggedIn` is
   true — allow a few minutes. Do **not** type credentials, do **not** click
   "Continue with Google/Apple", do **not** proceed without the user's
   explicit confirmation that they are logged in.

## 3. (Optional) start a fresh chat

Continue in the current conversation by default. For a clean context:

- `fx_click` on the sidebar "New chat" can fail with
  "could not be scrolled into view" (site CSS quirk). Verified fallback —
  `fx_eval`:

  ```js
  [].slice.call(document.querySelectorAll('button[aria-label="New chat"]'))
    .find(function(b) { return b.offsetParent !== null; }).click();
  ```

- Verify: URL is `https://chatgpt.com/` and the composer is empty.

## 4. Send the prompt

1. `fx_snapshot` → find the line `[div aria="Ask ChatGPT"` → its number is the
   composer **ref**.
   - The DOM contains **TWO** `contenteditable` composers — one is a hidden
     0×0 duplicate. Only the visible one appears in the snapshot. A CSS
     `querySelector` picks whichever comes first in DOM order, and that order
     is **not stable** — always use the snapshot ref.
2. `fx_type {ref: <composerRef>, text: "<prompt>"}` — real keystrokes; clears
   the composer first, which self-heals any stray/contaminated text.
3. Verify the text landed: `fx_text {ref: <composerRef>}` returns the prompt.
4. `fx_click {selector: 'button[aria-label="Send"]'}` — the Send button
   exists **only while the composer has text**.
5. Verify it was sent (~1.5 s later): the visible composer is empty **and**
   the URL changed to `/c/<uuid>`.
   - If it was NOT sent: re-run steps 2–4 (`fx_type` re-clears). Do **not**
     blindly re-click the Send button — that is how double-submits happen.
   - `fx_key {key: "Enter"}` is NOT reliable on this site (observed
     "not reachable by keyboard" / "could not be scrolled into view"
     failures) — use the Send button.

## 5. Wait for completion (the important part)

ChatGPT streams. There is no single "done" event — detect completion by
**text stabilization**. Verified poll (2 s cadence, in-page sleep):

```js
(function() {
  var last = document.querySelectorAll('[class*=DilResponseRoot]');
  var txt = last.length ? last[last.length - 1].innerText : '';
  var stopping = !!document.querySelector('button[aria-label="Stop"]');
  return { txtLen: txt.length, txt: txt, stopping: stopping };
})()
```

Loop (cap ~10 min):

1. `fx_eval` the snippet above → last answer text + Stop-button state.
2. **Complete** when: `txtLen > 0` AND the text is identical to the previous
   read (two consecutive reads 2 s apart) AND `stopping` is false.
3. Otherwise sleep in-page — `fx_eval` with
   `new Promise(function(r){ setTimeout(r, 2000); })` — and repeat.

Facts from live testing (2026-11-14):

- While generating: `button[aria-label="Stop"]` exists and the text grows.
- After completion: the Stop button is gone (an empty composer hides the
  Send button too).
- **Never use a broad label regex** (e.g. `/stop|send/i` over all buttons)
  as the completion gate: unrelated buttons match — observed a hidden
  floating-widget button titled "Restore floating chat: FAA Ground Stop
  Status" that matched `/stop/i` and made the loop poll ~40 times past
  completion. The **exact** selector `button[aria-label="Stop"]` is the only
  Stop check.
- `button[aria-label="Copy message"]` exists **during** streaming too — it is
  NOT a completion signal.
- The welcome screen contains **empty** `DilResponseRoot` elements — hence
  the `txtLen > 0` requirement.
- Some models show a "Thinking…" phase with no text at first — the loop
  tolerates leading empty reads.

If the cap is hit: report the timeout, return the partial text, and tell the
user the answer may still be streaming in the browser.

## 6. Extract the answer

`fx_text {selector: '[class*="DilResponseRoot"]', all: true, textLen: 0}` →
take the **last** entry = full text of the latest answer (verified with a
17 800-char response; `textLen: 0` disables truncation).

- Last entry, not first: entries are in DOM order.
- Off-screen older messages may be dropped by the visibility filter — that
  is fine, we only want the latest.
- Fallback if `fx_text` misbehaves: `fx_eval` the `innerText` of the last
  `[class*="DilResponseRoot"]`.

Present the answer to the user, noting it came from ChatGPT (their plan).

## Failure modes

| Symptom | Handling |
|---|---|
| `fx_click` → "could not be scrolled into view" | Site CSS quirk. JS `.click()` fallback via `fx_eval` (verified for sidebar buttons); for the composer use the snapshot ref + `fx_type`. |
| Stray text / literal key-escape artifacts in the composer | `fx_type` clears first — always `fx_type` right before sending, and verify the composer content before and after. |
| Rate-limit / "high demand" / "unusual activity" banner after sending | Stop, report to the user, do **not** auto-retry. |
| Login wall / CAPTCHA / native OS dialog mid-task | Human steps by design — hand to the user, wait, then resume. |
| Selectors stop matching (UI redesign) | Recover with `fx_snapshot` (visible-element map) + `fx_screenshot` + your own vision pass; report the drift. Substring class hooks: `group/user-message` (user turn), `DilResponseRoot` (assistant answer). |

## Guardrails

- The prompt (and any context you include) is sent to **OpenAI**. If the
  request contains secrets, keys, credentials, or personal data, warn the
  user before sending and get their confirmation.
- This consumes the user's ChatGPT plan usage — do not spam test prompts.
- Leave the browser in a usable state: don't close tabs, don't log out.
