# ShieldPal — Google Play listing

## App name (30)
ShieldPal: Scam & Link Guard

## Short description (80)
Scam, fake-link & QR checker with a cute pet that guards your phone. No ads.

## Full description (English)
ShieldPal is your cute cyber guardian. A little pet lives in the app and gets sick when your phone is in danger — and happy when you are safe.

🛡️ WHAT IT DOES
• Live Guard — catches scam links and scam messages in WhatsApp, SMS, Telegram and more, before you tap them. Shows which app and which chat they came from.
• Link Check — checks any link with offline rules plus Cloudflare, Google Safe Browsing and urlscan.io cloud checks, and shows where short links really go.
• Message Check — an on-device AI tells you if an SMS / WhatsApp message is a scam (English, Roman Urdu, Urdu, Hindi, Arabic, Spanish, Portuguese and more). It learns from your corrections.
• Safe QR — decodes a QR code before anything opens: phishing links, open Wi-Fi, payment QRs, crypto addresses.
• Deep Scan — checks screen lock, security patches, risky apps, spy-app powers and Google Play Protect, with one-tap Remove.
• Shield VPN — a local safety VPN that blocks dangerous websites (it does not hide your IP or change your country).
• Remote VPN — optional: run your own WireGuard config.
• Number Check — country, number type, network and warning signs (wangiri, premium, VoIP) plus the name from your own contacts.
• Password Check with a safe leak test, a built-in 2FA authenticator, and a Family Safe-Word to stop AI voice-clone scams.
• Pal AI — a friendly assistant that answers in your language, offline or online.
• "Scam or Safe?" — an endless swipe game that teaches you to spot scams. Earn coins, outfits and achievements for your pet.

🔒 PRIVACY FIRST
No account. No ads. No tracking. Messages and notifications are checked on your phone and are never uploaded. A few optional online checks send only a small piece of data (for example a website name) and only when you use them. You can delete everything in one tap.

🌍 14 LANGUAGES
English, اردو, Roman Urdu, हिन्दी, العربية, বাংলা, Español, Français, Português, Bahasa Indonesia, Türkçe, Русский, Deutsch, 中文.

Made by Faraz Labs.

## Roman Urdu description
ShieldPal ek pyaara cyber guardian hai. Is mein ek pet rehta hai jo aapka phone khatre mein ho to beemar ho jata hai aur mehfooz ho to khush.
• Live Guard WhatsApp/SMS ke scam links aur messages click se pehle pakadta hai.
• Link, Message, QR aur Number check, Deep Scan, Shield VPN (khatarnak websites band), 2FA, Family Safe-Word aur Pal AI.
• Na account, na ads, na tracking. Messages phone par check hote hain aur upload nahi hote.

## Category / tags
Tools → (or Communication). Tags: security, scam, phishing, VPN, QR scanner, antivirus, privacy.

## Contact
usmanfaraz1818@gmail.com — Privacy policy: host store/privacy_policy.html and paste its link.

## Graphics checklist
- App icon 512×512: store/play_icon_512.png (already generated)
- Feature graphic 1024×500: make in Canva with the logo (docs/logo.png), gradient #5B4BFF → #22C7E6 and the line "Your cute cyber guardian"
- 4–8 phone screenshots: Home, Link Check result, Message Check result, Deep Scan, Shield VPN, Pet shop

## Release checklist
1. Host the privacy policy and set kPrivacyUrl (lib/core/app_info.dart).
2. Fill Play Console forms from store/data_safety_and_forms.md (Data safety, VPN declaration, notification-listener and QUERY_ALL_PACKAGES declarations).
3. Back up android/upload-keystore.jks and android/key.properties (without them you cannot update the app).
4. Build: PowerShell → $env:ORG_GRADLE_PROJECT_play="true"; flutter build appbundle --release
   Upload build/app/outputs/bundle/release/app-release.aab to Play Console (Play App Signing).
5. Run flutter test before every release.
