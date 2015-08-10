# Tor for iOS

**This project is not affiliated with the [Tor Project](https://www.torproject.org/) in any way.** 

**What it is:** A framework for using Tor on iOS and a system wide proxy app to proxy traffic through it

**What works:**
- Tor, libevent, and OpenSSL compile the latest versions efficiently within Xcode, using automake.
- Tor is compiled into a dynamic framework, including `TORThread` to run Tor and `TORController` to control it.

**What needs work:**
- The packet tunnel provider needs to bridge raw network packets to and from Tor's SOCKS proxy (using something like [badvpn](https://github.com/ambrop72/badvpn)'s `tun2socks`).
- The packet tunnel provider needs to control Tor (handle going into the background, waking up, etc.)
- The UI for configuring common Tor options and displaying Tor status.

## Getting Started

### Prerequisites

- Xcode 7 or later
- GNU `gettext` (can be installed via [Homebrew](http://brew.sh/))
- A provisioning profile with Network Extension entitlements

### Building

1. Update `Tor.xcconfig` with your bundle identifiers
2. Checkout all of the submodules
3. Build with Xcode
