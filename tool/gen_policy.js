// Generates lib/core/policy_text.dart (shown inside the app) and
// store/privacy_policy.html (host it, e.g. on GitHub Pages, and paste the link
// in Play Console) from ONE source, so they can never disagree.
// Run:  node tool/gen_policy.js
const fs = require('fs');

const updated = '3 October 2026';
const contact = 'usmanfaraz1818@gmail.com';

const en = [
  ['The short version',
    '• ShieldPal has no account, no login and no servers of its own. We do not collect, store or sell your personal data.\n' +
    '• Messages, notifications, your list of apps, contacts and Deep Scan results are analysed ON YOUR PHONE and stay there.\n' +
    '• A few optional features send a small piece of data to a third-party service, only when you use them. They are all listed in section 3.\n' +
    '• No ads. No tracking or analytics. We never sell or share your data.'],
  ['1. What stays on your phone',
    '• Live Guard reads the text of new notifications (WhatsApp, SMS, Telegram…) to look for scam links and messages. The check happens on the device. If something dangerous is found, a short snippet plus the app and chat name are saved in your Threat Log on the phone. Nothing is uploaded.\n' +
    '• Message Check, the scam-detecting AI model, Number Check, Safe QR (camera pictures never leave the phone), Password strength, Family Safe-Word, the pet, coins and settings all work on the device.\n' +
    '• 2FA Vault secrets, API keys you add and your app-lock PIN are stored encrypted (Android Keystore). The PIN is stored only as a hash.\n' +
    '• Deep Scan reads your installed apps, their permissions and your phone\'s security settings on the device. The result is never uploaded.\n' +
    '• Contacts (optional): if you allow it, ShieldPal looks up the name you saved for a number you are checking. This happens on the phone; contacts are never uploaded or stored by ShieldPal.'],
  ['2. Account and identity',
    'ShieldPal needs no sign-up. We do not know who you are, and we do not collect your name, e-mail, phone number, location or advertising ID.'],
  ['3. What can leave your phone (optional)',
    'Only when you use the feature. Everything is sent over HTTPS.\n\n' +
    '• Link Check · Cloudflare Security DNS: the domain name of the link (for example "example.com"), never the full address or any personal detail. You can switch this off in Settings → Online services & AI.\n' +
    '• Link Check · Google Safe Browsing (only if you add your own key): the link address.\n' +
    '• Link Check · urlscan.io cloud browser (only if you add your own key and switch it on): the link address. urlscan.io opens the page far away from your phone and keeps the scan unlisted.\n' +
    '• Password Check · Have I Been Pwned: only the first 5 characters of the password\'s SHA-1 fingerprint (k-anonymity). Never the password itself.\n' +
    '• Pal AI · Free online AI (pollinations.ai): the text of your chat with Pal AI, only after you agree to it. Do not type passwords or codes into the chat. Turn it off any time in Settings; Pal AI also works fully offline.\n' +
    '• Pal AI · Claude by Anthropic (only if you add your own key): your chat messages, sent with your own key. Anthropic\'s privacy policy applies.\n' +
    '• Shield VPN: this is a local VPN on your phone. It does not send your traffic to ShieldPal or to any VPN server. Only your device\'s DNS lookups (the domain names your apps ask for) go to the DNS provider you choose in the app (Cloudflare, Google, Quad9, AdGuard or OpenDNS) — the same kind of lookups your phone normally sends to your mobile network. It does not hide your IP address.\n' +
    '• Remote VPN (optional): runs a WireGuard config that YOU paste. All your traffic then goes to the VPN server named in that config, so that provider can see it. ShieldPal stores the config encrypted on your phone only and never sends it anywhere else.\n' +
    '• Check my IP (optional button): asks ipwho.is for your public IP and country.\n' +
    '• Spoken warnings use the Android text-to-speech engine on your phone.\n\n' +
    'These services have their own privacy policies. ShieldPal gets none of this data.'],
  ['4. Permissions and why we ask',
    '• Internet — the optional online checks above.\n' +
    '• Notifications — to show threat alerts.\n' +
    '• Notification access — Live Guard (reading notifications on the device to find scams). You turn it on yourself in Android settings and can turn it off any time.\n' +
    '• Installed apps list (QUERY_ALL_PACKAGES) — Deep Scan and new-app warnings. The list stays on the device.\n' +
    '• Request delete packages — the one-tap "Remove" button for dangerous apps (you still confirm).\n' +
    '• Screen-lock strength — to tell you if your lock is weak (never your PIN).\n' +
    '• Camera — Safe QR scanner. Pictures are not saved or uploaded.\n' +
    '• Biometrics — fingerprint / face unlock for the app lock.\n' +
    '• Contacts (optional) — to show the saved name of a number.\n' +
    '• VPN service — the local DNS filter (Shield VPN). You approve the Android VPN dialog yourself.'],
  ['5. Security',
    'Online requests use HTTPS. Secrets are encrypted with the Android Keystore. The PIN is hashed. The app lock can use your fingerprint or face. ShieldPal does not back up its data to the cloud (allowBackup is off).'],
  ['6. Children and teens',
    'ShieldPal is made for everyone, including teenagers and families. It does not create accounts and does not knowingly collect personal data from anyone, including children under 13.'],
  ['7. Your choices and deleting your data',
    '• Settings → Privacy → "Delete all my data" erases everything ShieldPal stores on your phone: settings, threat log, 2FA codes, keys, PIN and pet progress.\n' +
    '• Uninstalling the app also removes all of it.\n' +
    '• You can revoke any permission or turn off Live Guard and Shield VPN in Android settings at any time.\n' +
    '• We hold no data about you on any server, so there is nothing to request from us. For data held by a third-party service, contact that service.'],
  ['8. Changes to this policy',
    'If features change, we update this policy here and in the app, and change the date above.'],
  ['9. Contact',
    'Faraz Labs — Usman Faraz\nE-mail: ' + contact],
];

const dartStr = (s) => "'" + s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n') + "'";
const dartList = (name, list) =>
  `const List<PolicySection> ${name} = [\n` +
  list.map(([t, b]) => `  PolicySection(${dartStr(t)}, ${dartStr(b)}),`).join('\n') +
  '\n];\n';

fs.writeFileSync('lib/core/policy_text.dart',
  `// GENERATED by tool/gen_policy.js - edit the script, not this file.
class PolicySection {
  final String title;
  final String body;
  const PolicySection(this.title, this.body);
}

const String policyUpdated = ${dartStr(updated)};
const String policyContact = ${dartStr(contact)};

${dartList('policyEn', en)}`);

const esc = (x) => x.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// Body text -> <p> and <ul><li> (same look as the Kryvo privacy page).
const body = (b) => {
  let out = '';
  let inList = false;
  for (const l of b.split('\n')) {
    if (l.startsWith('• ')) {
      if (!inList) { out += '<ul>\n'; inList = true; }
      out += '  <li>' + esc(l.slice(2)) + '</li>\n';
    } else {
      if (inList) { out += '</ul>\n'; inList = false; }
      if (l.trim()) out += '<p>' + esc(l) + '</p>\n';
    }
  }
  if (inList) out += '</ul>\n';
  return out;
};

// Entry 0 of "en" is the short version (shown in the box); the last entry is Contact.
const inShort = 'ShieldPal has no account and no servers of its own. Your messages, notifications, app list and scan ' +
  'results are checked on your phone and are never uploaded. A few optional online checks send one small piece of ' +
  'data (for example a website name) only when you use them. No ads, no tracking, and we never sell or share your data.';
const middle = en.slice(1, en.length - 1);
const sections = middle.map(([t, b]) => '<h2>' + esc(t) + '</h2>\n' + body(b)).join('\n');
const contactNo = en.length - 1;

fs.mkdirSync('store', { recursive: true });
fs.writeFileSync('store/privacy_policy.html',
  `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ShieldPal Privacy Policy</title>
<style>
  :root { --bg:#ffffff; --fg:#1a2230; --muted:#5b6678; --accent:#2b64d6; --line:#e3e8f0; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#0b0f17; --fg:#e7edf5; --muted:#93a1b5; --accent:#4f8cff; --line:#243044; }
  }
  body { margin:0; background:var(--bg); color:var(--fg);
         font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
  main { max-width:760px; margin:0 auto; padding:32px 16px 64px; }
  h1 { font-size:28px; margin:0 0 4px; }
  h2 { font-size:19px; margin:32px 0 8px; border-top:1px solid var(--line); padding-top:20px; }
  p, li { color:var(--fg); }
  .muted { color:var(--muted); }
  .box { border:1px solid var(--line); border-radius:12px; padding:14px 16px; }
  a { color:var(--accent); }
</style>
</head>
<body>
<main>
<h1>ShieldPal — Privacy Policy</h1>
<p class="muted">Developer: Faraz Labs · Last updated: ${updated}</p>

<div class="box">
<strong>In short:</strong> ${esc(inShort)}
</div>

${sections}
<h2>${contactNo}. Contact</h2>
<p>Questions? Email <a href="mailto:${contact}">${contact}</a>
or reach out on <a href="https://www.linkedin.com/in/usman-farazz">LinkedIn</a>.</p>
</main>
</body>
</html>
`);
console.log('policy generated');
