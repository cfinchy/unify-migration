# HA Dual-Instance Audit & Improvement Roadmap

*Created: 2026-03-15 | Living document — update as items are completed*

---

## Context

Two separate HA instances serve one family across two properties. This document
captures what each instance manages, whether the split still makes sense, where
they currently fail to communicate, and what improvements to prioritise.

---

## Instance Inventory

### Home HA — `ha.fnchysan.uk` (docker-host, 192.168.0.98:8123)

| Property | Value |
|----------|-------|
| Version | **2026.1.3** (current) |
| Integrations | 57 (HACS + built-in) |
| Devices / Entities | 396 / 2,486 |
| Automations | 126 |
| Scripts | 94 |

**Manages:**
- Lighting: Lutron Caseta (~40 dimmers), Philips Hue, Ring light groups
- AV: Marantz Cinema 40, LG OLED 77G3, Roku, AppleTV, Sonos multi-room, Epson projector
- Security: Ring (front/garden/gate/driveway), Frigate NVR, PlateRecognizer, Level Lock
- Climate: Nest thermostats, Dreo AC units
- Network: UDM-Pro monitoring (latency, clients, CPU/RAM)
- Presence: iCloud3 (4 members), WiFi detection, Aqara FP2 occupancy
- Voice: Alexa custom intents, Google GenAI assist, Amazon Polly TTS, OpenAI STT
- Notifications: Telegram bot (chat_id 1785328480) + mobile_app_iphone_caf

**Known broken automations (from 2026-03-11 audit):**
- [x] `1705882864243` — Marantz source test runs at midnight daily → deleted 2026-03-15
- [x] `1700000003` — `force_lg_tv_audio` fires when TV off → `state: 'on'` condition added 2026-03-15
- [x] `1700000005` — `block_unwanted_cec` template warning on off→on transition → guard added 2026-03-15

**Other known issues:**
- Level Lock Alexa Smart Home routine actions broken (March 2026 Amazon outage)
- Workaround active: direct voice command inline with PIN (`"unlock Laight with code 6111"`)
- TODO when Alexa app recovers: set Smart Home routine action → update scripts → restart HA

---

### Millcreek HA — `millcreek.duckdns.org`

| Property | Value |
|----------|-------|
| Version | **2026.3.1** (confirmed 2026-03-16, ahead of home HA) |
| Host | Debian Bookworm VM on VirtualBox, `K:\DebianVm\Bookworm` |
| Internal IP | `10.176.1.240` |
| SSH alias | `millcreek-ha` (ProxyJump via `millcreek-win`) |
| HA config | `/usr/share/hassio/homeassistant/` |
| Status | Phase 2 migration deferred to physical visit |
| Backups | `X:\HABackups` on home NAS |

**Confirmed integrations:**
- Alexa Media Player: ~40 Alexa devices (Echo, Echo Dot, Echo Show, Sonos, Brilliant)
- Mobile App: iphone_chris, iphone_chris_2, iphone_caf, ipad_pro, renes_iphone
- Telegram: `Millcreek_bot` (token hardcoded in configuration.yaml), `notify.millcreek`, chat_id 1785328480
- PlateRecognizer, doods object detection, camera integrations
- Lutron Caseta, Ring, MQTT/Shelly sensors, Govee lights
- Custom Lovelace dashboard at `/lovelace-millcreek/page-1`

**Gaps vs home HA:**
- [ ] No confirmed presence tracking
- [ ] No confirmed climate/thermostat integration (Nest config commented out)
- [ ] Unknown automation count (API access needs fresh long-lived token)
- [ ] No AI assist integration confirmed
- [ ] Telegram token hardcoded in configuration.yaml (should move to secrets.yaml)

**To get API access:**
1. Go to `https://millcreek.duckdns.org` → profile avatar → Security → Long-lived access tokens → Create
2. Save token to `~/millcreek-ha.token` (not in git, chmod 600)

---

## Architectural Assessment

**Two instances are the right call — but they're under-connected.**

Two properties on different ISPs/LANs require two instances: local device control
(Zigbee, Lutron, Z-Wave, etc.) requires LAN proximity. A single HA cannot manage
devices on two physically separate networks without cloud bridges for everything.

**But they currently act as two unrelated systems.** Key missing connections:
- Home HA doesn't know when family arrives/departs Millcreek
- Millcreek HA can't trigger home HA automations and vice versa
- No shared Telegram alerting from Millcreek (only mobile push)
- Millcreek dashboard not integrated into home HA frontend
- 6-month version gap means diverging feature sets and missed security fixes

---

## Improvement Roadmap

### Tier 1 — Do This Week (remote, no physical visit needed)

#### 1a. Add Telegram to Millcreek HA [x] — already configured

Found on 2026-03-16: Telegram was already set up in `configuration.yaml`.
- Bot: `Millcreek_bot` (different token from home HA bot, both valid)
- Notify service: `notify.millcreek`
- Same chat_id: `1785328480` — alerts land in the same Telegram chat
- **Remaining**: Move token from hardcoded in configuration.yaml to `secrets.yaml`

#### 1b. Fix home HA broken automations [x] — 2026-03-15

- [ ] Delete `1705882864243` (Marantz midnight source test — running in production)
- [ ] Fix `1700000003`: add condition `state: media_player.lg_webos_tv_oled77g3pua == 'on'`
- [ ] Fix `1700000005`: add guard for off→on transition to suppress template warning
- Access: `http://192.168.0.98:8123` → Settings → Automations

#### 1c. Update Millcreek HA version [x] — already on 2026.3.1

Confirmed 2026-03-16: Millcreek HA is at `2026.3.1`, ahead of home HA (`2026.1.3`).

---

### Tier 2 — Next 2–3 Weeks (remote)

#### 2a. Cross-instance presence sharing [ ]

When a family member's iCloud shows them at Millcreek zone, home HA should know.

Implementation: HA webhooks
- Millcreek HA: automation on `person` state change → POST to home HA webhook
- Home HA: automation with `webhook` trigger → update `input_boolean` or virtual sensor

Steps:
1. Create webhook ID on home HA: Settings → Automations → trigger: Webhook → note the ID
2. Millcreek HA automation fires `rest_command` to `https://ha.fnchysan.uk/api/webhook/<id>`
3. Repeat in reverse (home HA notifies Millcreek on departure)
4. Create `zone.millcreek` on home HA at Millcreek coordinates

#### 2b. Shared Lovelace views — DEFERRED (cleanup item)

`panel_iframe` works on desktop browser (one login required, then persistent) but
breaks on the Companion app — webview doesn't share cookies, auth wall hits every
time, interactive elements unreliable.

**Better approach for mobile: Companion app multi-server** — add both HA instances
as separate servers, switch with a tap. Full native experience, no auth wall.

- [ ] Set up multi-server on Companion app (Settings → Companion app → Add server → `millcreek.duckdns.org`)
- [ ] Skip `panel_iframe` unless desktop-only use case arises

#### 2c. Cross-instance notification routing [ ]

- Create `script.notify_family` on each instance: sends to Telegram + mobile push
- Standardise all automation `notify` calls to use the script (single point to update)
- Home HA script example:
  ```yaml
  notify_family:
    sequence:
      - service: notify.telegram_home
        data: { message: "{{ message }}" }
      - service: notify.mobile_app_iphone_caf
        data: { message: "{{ message }}" }
  ```

---

### Tier 3 — At Physical Visit + After Migration

#### 3a. Complete Millcreek HA migration (Phase 2 from PLAN.md) [ ]

- New Debian VM on C: with HA Supervised
- Restore from backup (`9ff1dfa6.tar`, 4.91 GB on X:\HABackups)
- Move off VirtualBox + Passport/K: drive (K: has prior CRC errors — data at risk)
- Cutover via `cutover_vm.ps1` (MAC swap + static IP — see PLAN.md)
- Enables: SSH add-on, proper console access, stable long-term home

#### 3b. Full Millcreek HA audit (needs API access after migration) [ ]

- Deep inventory: all integrations, automations, devices, entities
- Identify further gaps vs home HA baseline
- Check for broken/stale automations (same process as home HA 2026-03-11 audit)
- Document results in `/tmp/unify-migration/docs/millcreek-ha-audit.md`

#### 3c. Climate integration at Millcreek [ ]

- Confirm if Nest or other thermostat is integrated
- If not, add it so both properties have remote climate control
- Add to home HA frontend view once confirmed

#### 3d. Security camera integration at Millcreek [ ]

- Confirm if cameras exist at property
- Add Frigate or similar NVR if available
- Connect alerts to home HA via cross-instance webhook for unified alert routing
- Consider PlateRecognizer integration if driveway camera present

---

## Verification Checklist

| Item | Test | Status |
|------|------|--------|
| Telegram on Millcreek | Already configured — Millcreek_bot valid, notify.millcreek exists | [x] 2026-03-16 |
| Millcreek version | 2026.3.1 confirmed via SSH | [x] 2026-03-16 |
| Home HA broken automations | Automation reloaded, marantz_source_test = unavailable | [x] 2026-03-15 |
| Cross-instance presence | Manually trigger zone change → both HAs reflect it | [ ] |
| Lovelace / multi-server | Companion app multi-server setup (skip iframe) | [ ] deferred |
| Notification script | Single script call → Telegram + mobile both receive | [ ] |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-03-15 | Document created from audit session |
| 2026-03-15 | Tier 1b complete: deleted marantz midnight test, fixed force_lg_tv_audio (TV=on condition), fixed block_unwanted_cec (off→on guard) |
| 2026-03-16 | Tier 1a + 1c already done: Telegram (Millcreek_bot) and HA 2026.3.1 were pre-existing. SSH key auth set up, millcreek-ha alias added, credentials stored. |
