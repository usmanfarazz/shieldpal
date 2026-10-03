# ShieldPal — Play Console forms (answers)

These answers describe ShieldPal v1.1.0 **as built today**. If a feature changes, change the answers too.
The privacy policy text lives in `tool/gen_policy.js` (run `node tool/gen_policy.js`, then host
`store/privacy_policy.html` and put its link in `lib/core/app_info.dart` → `kPrivacyUrl` and in Play Console).

---

## 1. Data safety  (Policy → App content → Data safety)

ShieldPal has **no server and no account**. "Collected" in Google's sense means *sent off the device*.
Everything below is optional and only happens when the user uses that feature.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (optional features send small pieces to third-party services) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS everywhere; VPN/DNS lookups go to the DNS provider the user picks) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — Settings → Delete all my data (nothing is stored on any server) |

**Data types sent off the device (all optional, none sold, none used for ads):**

| Data type | Sent? | Shared with | Purpose | Notes |
|---|---|---|---|---|
| Web browsing → **Web browsing history** (link addresses / website names) | Yes, only when the user checks a link / QR / message | Cloudflare (website name), Google Safe Browsing & urlscan.io (full link, only if the user adds their own key) | App functionality (security) | User-initiated |
| App activity → **Other user-generated content** (chat text with Pal AI) | Yes, only if the user turns on Free online AI or adds a Claude key | pollinations.ai / Anthropic | App functionality | Consent dialog on first use; off in Settings |
| Passwords → (leak check) | Only 5 characters of a SHA-1 hash | Have I Been Pwned | App functionality (security) | Never the password; k-anonymity |
| Device or other IDs / Location / Contacts / Messages / Photos / Financial | **No** | — | — | Contacts are read on the phone only to show a saved name (optional) and are never uploaded |

Mark each as **"Collection is optional"** and **not shared for advertising**. Declare the data as processed
**ephemerally** where Play offers it (nothing is stored by us).

---

## 2. Privacy policy

Host `store/privacy_policy.html` (GitHub Pages works) and paste the link in Play Console and in `kPrivacyUrl`.

---

## 3. Sensitive permissions & declarations (be ready to justify each one)

| Permission / feature | Why (text for the declaration form) |
|---|---|
| `BIND_NOTIFICATION_LISTENER_SERVICE` (Live Guard) | Core feature: reads incoming notifications **on the device** to detect scam links/messages and warn the user. Not uploaded. User enables it in system settings. |
| `QUERY_ALL_PACKAGES` | Core feature of a security app: Deep Scan inspects installed apps and permissions to find risky/malicious apps. Not uploaded. |
| `BIND_VPN_SERVICE` (Shield VPN) | Local VPN that filters dangerous domains (DNS) and forwards all other traffic unchanged. No traffic goes to our servers. |
| VPN (Remote VPN / WireGuard) | Optional: runs the **user's own** WireGuard config. Disclose in the listing that traffic goes to the server the user configured. |
| `REQUEST_DELETE_PACKAGES` | One-tap "Remove" for dangerous apps; the user confirms in the system dialog. |
| `READ_CONTACTS` (optional) | Shows the name the user saved for a number they are checking. On-device only. |
| `CAMERA` | Safe QR scanner; pictures are not saved or uploaded. |
| `USE_BIOMETRIC` | Fingerprint / face unlock for the app lock. |
| `POST_NOTIFICATIONS` | Threat alerts. |
| `INTERNET` | Optional online checks listed in the Data safety section. |

VPN apps must complete Google's **VPN service declaration** and may not collect user data or sell it; ShieldPal does neither.

---

## 4. App access
All functionality is available without login or special access.

## 5. Ads
**No ads.**

## 6. Content rating (IARC)
Category: **Utility / Productivity / Tools**. No violence, sexuality, gambling or user-to-user chat.
(Mentions of scams are educational.)

## 7. Target audience
General audience incl. teenagers; **not** designed primarily for children under 13. No accounts and no data collection.

## 8. Listing notes
- Say clearly: "Shield VPN is a local safety VPN. It does not hide your IP or change your country."
- Say clearly: "The registered owner of a phone number is private; ShieldPal cannot show it."
- Do not use the words "unblock websites" for the Remote VPN in a way that promises access to blocked content.
