# Training Call — stripped-down WebRTC video/audio app

A single web page for a direct video + audio call between you and Maria.
No installs, no accounts, no third-party app in the middle.

## How it works

- **`server.js`** — a tiny signaling server. It only relays a handful of
  small text messages so the two browsers can find each other. It never
  touches video or audio.
- **`public/index.html`** — the page both of you open. Once the handshake
  is done, video/audio flows directly between your devices.

## Deploying to Render (free tier, ~10 minutes, one time)

1. **Create a GitHub repo** (if you don't already use GitHub, this is the
   easiest path — Render deploys straight from a repo):
   - Go to github.com, sign in (or create a free account)
   - Click "New repository", name it `training-call`, keep it Public or
     Private (either works), don't add a README
   - On your PC, in a terminal, inside this `webrtc-app` folder:
     ```
     git init
     git add .
     git commit -m "initial commit"
     git branch -M main
     git remote add origin https://github.com/YOUR_USERNAME/training-call.git
     git push -u origin main
     ```
   - (Replace YOUR_USERNAME with your actual GitHub username)

2. **Create the Render service:**
   - Go to render.com, sign up free (you can use your GitHub account to
     sign in, which also makes step 3 automatic)
   - Click "New +" → "Web Service"
   - Connect your `training-call` repo
   - Render should auto-detect Node. Confirm these settings:
     - **Build Command:** `npm install`
     - **Start Command:** `npm start`
     - **Instance Type:** Free
   - Click "Create Web Service"

3. **Wait for the first deploy** (2-3 minutes). Render gives you a URL like:
   ```
   https://training-call-xxxx.onrender.com
   ```

4. **That URL is the link you both use.** Send it to Maria once. Whoever
   opens it first waits; whoever opens it second connects the call
   automatically.

### One honest caveat about the free tier

Render's free web services go to sleep after 15 minutes of no traffic, and
take ~30-60 seconds to "wake up" on the next visit. In practice: if you
haven't used the link in a while, the first call attempt of the day might
just need an extra 30-60 seconds before it connects — open the page, wait,
then tap Start Call. After that it stays warm for the rest of the session.

If that wake-up delay ever becomes annoying, Render's paid tier ($7/month)
removes it — but I'd try the free tier first since your call frequency
probably won't make that worth paying for.

## Using it

1. Open the URL on your gym PC in Chromium.
2. In the camera dropdown, select the **EMEET PIXY** specifically (not
   whatever default shows first) — this is the whole point of the app,
   getting a direct line to that camera without OBS in between.
3. Pick your mic.
4. Tap **Start Call**.
5. Send Maria the same link (works in any browser, any device — phone,
   laptop, tablet). She taps **Start Call** on her end too.
6. Whoever opens second triggers the connection automatically — no meeting
   ID, no code, nothing to read out loud.

## If a call won't connect

This would almost always mean one of you is behind a network that blocks
direct peer-to-peer connections (some corporate/public Wi-Fi does this;
home networks with normal NAT — including yours behind the UDM-SE — should
be fine). If it happens consistently, the fix is adding a TURN server as a
relay fallback — let me know and we can add one (a free-tier TURN service
like Metered.ca would slot in with about 5 lines of code).

## Applying this update (you already have this deployed on Render)

Since the app is already live, you don't need to redo the GitHub/Render
setup — just replace the updated files and push:

1. Copy the new `public/index.html`, `launch-training-call.sh`, and
   `TrainingCall.desktop` from this update into your existing
   `~/training-call/webrtc-app` folder, overwriting the old `index.html`.

2. From inside that folder:
   ```
   git add .
   git commit -m "add fullscreen mode and one-step auto-start"
   git push
   ```

3. Render watches your GitHub repo and redeploys automatically within
   about a minute of the push — no need to touch the Render dashboard.
   You can confirm it picked up the change by checking the deploy log on
   Render for a new "Live" entry with your latest commit message.

## What's new: one-step startup and fullscreen

The app now does two extra things automatically:

- **Remembers your camera and mic.** Once you've picked the EMEET PIXY from
  the dropdown one time, your browser remembers it (saved locally on that
  PC) and auto-selects it every time after.
- **Starts the call automatically.** The moment the page loads and camera
  permission is already granted, it connects on its own — no need to tap
  "Start Call" each time. (You'd still tap it once, manually, after ending
  a call, to start a new one.)

There's also a **Fullscreen** button. Tapping it fills the entire screen
with the video and fades away the header/footer controls after a few
seconds of no mouse movement — move the mouse, tap the screen, or press
any key to bring the controls back.

## A note on Fullscreen and iPhone

The Fullscreen button works fully on the gym PC (any Chromium/Firefox
desktop browser). On iPhone, it won't do anything when tapped — this is an
Apple platform restriction, not a bug: iOS only allows the Fullscreen API
on `<video>` elements, never on a whole page, across every browser on
iPhone (they're all required to use Safari's engine underneath).

The real fix on iPhone is **adding the page to the Home Screen**: in
Safari, tap the Share icon → "Add to Home Screen". Opening the call from
that Home Screen icon (instead of from inside Safari) makes iOS hide the
address bar and browser chrome automatically, every time — true
fullscreen, no button needed. Worth setting up once on Maria's phone.

## Setting up one-click startup on the gym PC

Two files came with this update: `launch-training-call.sh` and
`TrainingCall.desktop`. Together they turn "open browser, type URL" into a
single double-click.

1. **Copy the launcher script into your project folder** (if it isn't
   already there) and make it executable:
   ```
   chmod +x ~/training-call/webrtc-app/launch-training-call.sh
   ```

2. **Put the desktop icon on your Desktop:**
   ```
   cp ~/training-call/webrtc-app/TrainingCall.desktop ~/Desktop/
   chmod +x ~/Desktop/TrainingCall.desktop
   ```

3. The first time you double-click it, Linux Mint will likely ask whether
   to trust it — right-click the icon and choose **"Allow Launching"** if
   double-clicking doesn't immediately work, then try again.

From then on: double-click the **Training Call** icon on your Desktop, and
it opens straight into a full-screen call window with your camera/mic
already selected and the call already connecting. That's the entire
startup procedure.

(If the icon shows the wrong username/path for some reason — for example,
if you ever set this up under a different account — open
`TrainingCall.desktop` in a text editor and fix the `Exec=` line to point
at the correct path.)

## Running it locally first (optional, to test before deploying)

```
npm install
npm start
```
Then open `http://localhost:3000` in two browser tabs to test the handshake
on one machine before deploying. Camera/mic access over plain `http://`
only works on `localhost` — once deployed, Render's HTTPS handles this
automatically for both of you.
