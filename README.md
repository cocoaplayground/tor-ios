# Tor for iOS 9+

**What it is:** A system wide, App Store safe, Tor proxy for iOS 9 and later. **It doesn't work yet. It is not affiliated with the [Tor Project](https://www.torproject.org/) in any way.** 

**What works:**
- Tor, libevent, and OpenSSL compile the latest versions efficiently within Xcode, using automake.
- Tor runs successfully on its own thread, with an Objective-C client for its control port to control it.

**What needs work:**
- The proper entitlements for the network extension have not been requested from Apple yet, so the extension cannot be installed on a device.
- The packet tunnel provider is not started yet. It needs to bridge raw network packets to and from Tor's SOCKS proxy (using something like [badvpn](https://github.com/ambrop72/badvpn)'s `tun2socks`).
- The UI for configuring common Tor options and passing them to the extension is not implemented yet.

## Building

You need the following prerequisites:

- Xcode 7 or later
- GNU `gettext` (can be installed via [Homebrew](http://brew.sh/))

To build the project, checkout all of the submodules and build it within Xcode.
