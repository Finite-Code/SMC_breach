# SMC_breach

A sleek macOS menu bar utility that dives into hidden system APIs to broadcast live power consumption, battery health, and logic board stats.

<img width="1256" height="920" alt="Screen Recording 2026-07-31 at 00 47 53" src="https://github.com/user-attachments/assets/1aa64d75-ec11-4836-96d1-ff6d0b12f3d5" />

**[🚀 DOWNLOAD THE LATEST DEMO RELEASE HERE](https://www.google.com/search?q=https://github.com/your-username/SMC_breach/releases)**

## Quick start

How to go from 0 to live internal data states in under 10 seconds:

1. Download the `.pkg` from the link above.
2. **IMPORTANT:** Follow along the install guide in Releases.
3. Open it up! It lives quietly up top as a menu bar extra (no annoying Dock clutter).

## Features

The Demo UI is fully plugged in, pulling metrics directly from your machine.

* **Live Battery Power:** Precise real-time wattage actively routing into the battery for charging, or being pulled for discharging (calculated with proper directional signs).
* **Adapter Wattage:** Displays the total DC power entering the machine’s logic board directly from the external AC adapter.
* **System Power Load:** Live system load/uptime tracking alongside raw battery capacity.
* **Menu Bar Native:** A pure `.menuBarExtra` SwiftUI app. It's completely out of your way until you need it.
* **Liquid Glass:** Beautifully grouped layout utilizing SF Symbols to get the best of UX and a delight to the eye.

## How to run it locally

Wanna breach the SMC yourself? It's pretty straightforward, just make sure you have Xcode installed.

```bash
# Clone the repository
git clone https://github.com/Finite-Code/SMC_breach.git

# Navigate into the project
cd SMC_breach

```

Just open the project folder in Xcode, let the indexing finish, and hit `Cmd + R` to build and run. (Targets Apple Silicon/macOS architecture).

## How it works

macOS doesn't natively broadcast a lot of this power information to standard applications, so you have to go through hidden system APIs. This is exactly why such Power Management apps are never on the App Store!

Under the hood, the app leverages IOKit (via Objective-C bridging) to dig into the macOS power and battery subsystem. We connect directly to the `AppleSmartBattery` service in the IORegistry. On M1 and beyond architectures, Apple introduced a detailed sub-dictionary called `PowerTelemetryData`. My `PowerMonitor` ObservableObject uses a timer to safely extract amperage, voltage, and internal states directly from these nodes.

To make this robust, everything is fetched using C functions and safely dispatched back to the main queue for SwiftUI to update the `@Published` properties. I also heavily relied on `defer { IOObjectRelease(...) }` to ensure we don't leak memory from CoreFoundation objects while keeping the live stats refreshing every second.

## Credits / Acknowledgements

What's up folks? This is Atharva (FiniteCode), and I couldn't have pulled off this low-level access without:

* **The OSS Community:** For the extensive research and forum posts that helped me crack into the `AppleSmartBattery` nodes.
* **AI Assistants:** Gemini and Claude for the heavy lifting on researching the obscure `powermetrics` IOKit C APIs (`IOReportCopyChannelsInGroup`, etc.).
* **Stardance:** For the hackathon infrastructure, what actually motivated me to make this!

---

*Stay tuned, I've got something a lot bigger going on next! XD*
