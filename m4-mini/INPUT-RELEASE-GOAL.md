# Release goal: effortless Apple and Logitech input on the M4 Mac mini

**Status: planned; no devices or pairing behavior have been qualified yet.**

Make the base M4 Mac mini usable with its owner's Apple Magic Keyboard, Magic Trackpad and Magic Mouse, and Logitech keyboard and mouse, with pairing that is simple to set up, remembered, and automatically restored. Prioritize the experience of plugging in the device or receiver and using it, then using the device wirelessly without repeating setup.

## Acceptance criteria

- **Bluetooth foundation:** The mini's internal Bluetooth controller starts reliably with the selected kernel and firmware. Bluetooth is available at the login screen, and a previously paired keyboard and pointing device reconnect after restart, device power cycle, and supported sleep/wake. Wired input remains usable if pairing fails.
- **Apple Magic devices:** For supported USB-C or Lightning models, investigate and implement cable-assisted pairing so connecting a powered-on keyboard, trackpad or mouse by a data cable can establish a persistent Bluetooth bond. After unplugging, it reconnects and is usable wirelessly. Validate typing, pointer movement and clicks, and trackpad scrolling and gestures as applicable. If a particular model cannot be cable paired on Linux, provide a clear guided Bluetooth pairing flow and record that model's limitation; do not claim this criterion is met for it.
- **Logitech Bluetooth and channels:** Support a Logitech Wave keyboard and the owner's mouse once exact models are identified. Let the user select an unused Easy-Switch channel on the device, pair it with the mini, and reconnect after restart and switching away and back. Preserve the other channels and other computers' pairings. Do not assume the OS can discover which channel is free, or overwrite one automatically. If the device requires a button press or passcode, guide the user through it.
- **Logitech receivers:** An already-paired compatible receiver should work when plugged in. For a compatible unpaired Bolt or Unifying receiver, provide a discoverable pairing path using available Linux tooling, with the user selecting a device/channel and completing any authentication. Receiver pairing and direct Bluetooth pairing are separate paths; do not describe the receiver as a Bluetooth connection or replace existing receiver pairings silently.
- **Saved means saved:** Verify a durable bond and actual reconnect, not merely a temporary connection or a trusted flag. Use the Bluetooth service's supported interfaces and verify results after reboot. Do not log or expose pairing keys.
- **Qualification:** Record exact device model and revision, cable or receiver type, M4 kernel/firmware/BlueZ versions, transport, channel where relevant, test steps and results. Run the acceptance tests on the M4 mini when it is ready for hardware testing. Mark failures and models requiring a guided step honestly.

## Research starting points

- Apple documents USB-assisted pairing for current Magic accessories on macOS: [Apple setup guide](https://support.apple.com/en-gb/119917). Linux behavior and device-generation coverage are still to be established.
- Logitech describes Easy-Switch channel selection and supported devices, including Wave Keys: [Logitech Easy-Switch guide](https://www.logitech.com/en-au/discover/a/easy-switch-technology). Exact mouse and keyboard models must be confirmed.
- [Solaar](https://github.com/pwr-Solaar/Solaar) supports Linux management and receiver pairing for many Logitech devices; compatibility and packaging need to be checked for each device. Its [receiver documentation](https://github.com/pwr-Solaar/Solaar/blob/master/docs/capabilities.md) describes receiver capacity and pairing differences.
- [BlueZ's device API](https://github.com/bluez/bluez/blob/master/doc/org.bluez.Device.rst) distinguishes a persistent bond from pairing, connection and trust. Its [storage documentation](https://github.com/bluez/bluez/blob/master/doc/settings-storage.txt) discourages direct external edits to Bluetooth state.
