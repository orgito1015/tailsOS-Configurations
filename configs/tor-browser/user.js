// configs/tor-browser/user.js
// =============================================================================
// Tor Browser hardening user.js
// =============================================================================
// USAGE:
//   Copy this file into the Tor Browser profile directory.
//   The profile directory is usually at:
//     ~/.tor-browser/profile.default/
//   or, in Tails:
//     /home/amnesia/.tor-browser/profile.default/
//
//   Then restart Tor Browser.
//
// WARNING: Tor Browser already applies strong hardening via its own
//   settings and the Torbutton extension.  The preferences below ADD to
//   those defaults.  Do not remove or override Tor Browser's built-in
//   security settings.
//
//   These settings target the "Safest" security level as a baseline, and
//   then restrict additional attack surface beyond it.
//
// RISK: Some of these settings will break websites.  That is intentional —
//   the goal is to protect privacy, not to maximise browsing convenience.
// =============================================================================

// ── Security level: enforce "Safest" ─────────────────────────────────────────
// 1 = Standard, 2 = Safer, 4 = Safest
user_pref("extensions.torbutton.security_slider", 4);

// ── WebGL — disable (largest attack surface in most browsers) ────────────────
user_pref("webgl.disabled", true);
user_pref("webgl.enable-webgl2", false);
// Prevent WebGL renderer info from being exposed even if WebGL is on
user_pref("webgl.enable-renderer-info", false);

// ── JavaScript — disabled by default at "Safest" level; confirm here ─────────
// (Torbutton handles this via the security slider; these reinforce it.)
user_pref("javascript.enabled", false);

// ── Canvas fingerprinting ─────────────────────────────────────────────────────
// Tor Browser already prompts on canvas reads at Safer/Safest.
// This explicitly blocks all canvas data extraction.
user_pref("privacy.resistFingerprinting", true);

// ── Media ─────────────────────────────────────────────────────────────────────
user_pref("media.peerconnection.enabled", false);     // WebRTC — IP leak risk
user_pref("media.video_stats.enabled", false);
user_pref("media.navigator.enabled", false);
user_pref("media.autoplay.default", 5);               // Block autoplay completely

// ── Geolocation ───────────────────────────────────────────────────────────────
user_pref("geo.enabled", false);
user_pref("geo.provider.use_gpsd", false);
user_pref("geo.provider.use_geoclue", false);

// ── DOM storage ───────────────────────────────────────────────────────────────
user_pref("dom.storage.enabled", false);              // Disable localStorage
user_pref("dom.indexedDB.enabled", false);
user_pref("dom.caches.enabled", false);

// ── Battery / sensors APIs ────────────────────────────────────────────────────
user_pref("dom.battery.enabled", false);
user_pref("dom.gamepad.enabled", false);
user_pref("dom.vr.enabled", false);

// ── Service Workers / Push ────────────────────────────────────────────────────
user_pref("dom.serviceWorkers.enabled", false);
user_pref("dom.push.enabled", false);
user_pref("dom.push.connection.enabled", false);

// ── Network ───────────────────────────────────────────────────────────────────
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.predictor.enabled", false);

// Disable WebSockets (can bypass Tor proxy in misconfigured setups)
user_pref("network.websocket.enabled", false);

// Enforce HTTPS (complementary to HTTPS-Only mode in Tor Browser)
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// ── Telemetry / data collection ───────────────────────────────────────────────
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.server", "");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.crashReports.unsubmittedCheck.enabled", false);

// ── Safe Browsing (contacts Google servers) ───────────────────────────────────
// Tor Browser disables this by default; confirm here.
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.downloads.enabled", false);

// ── Fonts ─────────────────────────────────────────────────────────────────────
// Restrict to system fonts only to prevent font fingerprinting.
user_pref("browser.display.use_document_fonts", 0);

// ── Misc fingerprinting resistance ────────────────────────────────────────────
user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);
user_pref("browser.startup.homepage_override.mstone", "ignore");

// ── Disk / cache ──────────────────────────────────────────────────────────────
// Tor Browser uses an in-memory cache; these ensure nothing is written to disk.
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.offline.enable", false);
user_pref("browser.privatebrowsing.autostart", true);
