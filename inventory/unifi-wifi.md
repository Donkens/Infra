# UniFi WiFi

> Current WLAN/SSID source-of-truth.
> Last verified: 2026-05-06 CEST (element SSID audit)

## WLANs

| SSID | Status | Network / VLAN | Bands | Security | PMF | WPA3 transition | 802.11r / fast roaming | MLO enabled | Hidden | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| `UniFi` | LIVE | Default / untagged | 5 GHz | `wpapsk`, `wpa2`, `ccmp` | optional | true | false | false | false | Main trusted SSID. |
| `UniFi IOT` | LIVE | IOT / VLAN 10 | 2.4 GHz | `wpapsk`, `wpa2`, `ccmp` | disabled | false | false | false | false | IoT SSID. |
| `UniFi MLO/6Ghz` | LIVE | MLO-LAN / VLAN 40 | 6 GHz | `wpapsk`, `wpa2`, `ccmp` | required | false | false | false | false | 6 GHz radio is active, but controller reports `mlo_enabled=false`; treat MLO status as DRIFT/UNKNOWN. |
| `Unifi Why Guest` | DISABLED | UniFi Guest / VLAN 20 | 2.4/5/6 GHz | `wpapsk`, `wpa2`, `ccmp` | optional | true | false | UNKNOWN | false | Guest SSID and guest network are disabled. |
| `element-b85dc41a14f3982d` | GONE | — | — | — | — | — | — | — | — | Not present in controller WLAN list or RF scan (115 neighbors), 2026-05-06 Phase 0 audit. Documented 2026-04-28 with UNKNOWN network/VLAN — never a controller-managed WLAN. Likely transient external device (neighbor/IoT setup). Risk: none. Safe to remove from inventory. |

## Radio observations

| Radio | Channel | Width | Tx power | SSID observed | Status |
|---|---:|---:|---:|---|---|
| 2.4 GHz | `6` | `20 MHz` | `13 dBm` | `UniFi IOT` | VERIFIED |
| 5 GHz | `48` | `80 MHz` | `16 dBm` | `UniFi` | VERIFIED |
| 6 GHz | `37` | `320 MHz` | `17 dBm` | `UniFi MLO/6Ghz` | VERIFIED |

## Notes

- `UniFi MLO/6Ghz` is on MLO-LAN/VLAN 40, but controller data reports `mlo_enabled=false`.
- The radio/driver exposes MLD interfaces, so operational MLO support should be treated as DRIFT/UNKNOWN until a client-side test confirms behavior.
- Do not store WLAN credentials in this repository.
