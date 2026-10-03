import '../l10n/l10n.dart';

/// "Cyber tip of the day". One tip per calendar day, same for everyone.
/// English and Roman Urdu are written out; other languages fall back to English.
class Tips {
  static const List<String> en = [
    'No real company, bank or game ever asks for your OTP. Anyone who asks is a scammer.',
    'Turn on two-factor authentication (2FA) for WhatsApp, Instagram and your email first.',
    'A link that promises free diamonds, robux or UC is almost always a trap. Never log in through it.',
    'Check the web address, not the logo. "garena.com" is real, "garena-event.xyz" is not.',
    'Use a different password for every important account. A password manager or ShieldPal\'s generator helps.',
    'Long passphrases beat short complex passwords: "blue-mango-cricket-9" is stronger than "P@ss1".',
    'If someone you know asks for money from a new number, call their old number first.',
    'AI can clone a voice from a few seconds of audio. Agree a family safe-word and use it on urgent money calls.',
    'Public Wi-Fi is fine for browsing but never log in to your bank on it.',
    'Install apps only from Google Play. "Mod APK" files often hide spyware.',
    'Keep your phone updated. Security patches close the holes hackers use.',
    'Pause before you click. Scammers use urgency ("within 1 hour!") so you do not think.',
    'Do not scan QR codes stuck on poles, parking meters or sent by strangers. They can hide a bad link.',
    'Cover your PIN when typing it and never save card details on shared devices.',
    'If you clicked a bad link, do not panic: change your passwords from a safe device and turn on 2FA.',
    'Your CNIC, passport and OTP are keys to your identity. Share them only with official, verified places.',
    'A job that asks you to pay a "registration fee" first is a scam.',
    'A prize you never entered for is not a prize. Delete the message.',
    'Check which apps have accessibility, camera and microphone access. Remove what you do not need.',
    'Use a screen lock with a PIN or fingerprint. Swipe-only or simple patterns are easy to guess.',
    'Never share your screen or install remote-control apps (AnyDesk, TeamViewer) for a stranger who "helps" you.',
    'Back up photos and chats regularly. If your phone is lost or locked by ransomware you still have them.',
    'Be careful what you post: birthdays, school, location and travel plans help scammers guess answers and plan.',
    'Short links (bit.ly, tinyurl) hide the real address. Check them in ShieldPal before opening.',
    'Fake delivery messages ("your parcel is on hold, pay Rs 50") are very common. Track the parcel in the courier\'s own app.',
    'Unknown number calling you "from the bank"? Hang up and call the number printed on your card.',
    'Log out of accounts on shared computers and never tick "remember me" there.',
    'Turn on Play Protect: Play Store → profile → Play Protect → Scan apps.',
    'Report scam numbers and messages. It protects other people too.',
    'Gaming accounts are targets. Link them to a real email and add 2FA before you need recovery.',
    'Look at the sender, not only the name. Anyone can name themselves "Bank Alert".',
    'If a deal is too good to be true, it is. Guaranteed profit does not exist.',
    'Update your recovery email and phone number so you can get your account back if it is hacked.',
    'Bluetooth and hotspot: turn them off when you are not using them.',
    'Teach your parents and grandparents the OTP rule. They are the most common targets.',
  ];

  static const List<String> rur = [
    'Koi asli company, bank ya game kabhi aap se OTP nahi mangta. Jo mange woh scammer hai.',
    'Sab se pehle WhatsApp, Instagram aur email par two-factor authentication (2FA) on karein.',
    'Free diamonds, robux ya UC ka link taqreeban hamesha jaal hota hai. Us se kabhi login na karein.',
    'Logo nahi, web address dekhein. "garena.com" asli hai, "garena-event.xyz" nahi.',
    'Har important account ka alag password rakhein. Password manager ya ShieldPal ka generator madad karta hai.',
    'Lambay passphrase chhotay mushkil passwords se behtar hain: "neela-aam-cricket-9" "P@ss1" se mazboot hai.',
    'Agar koi jaanne wala naye number se paise mange, pehle uske purane number par call karein.',
    'AI chand second ki audio se awaaz copy kar sakta hai. Ghar walon ka safe-word rakhein aur paison ki call par use karein.',
    'Public Wi-Fi browsing ke liye theek hai, lekin us par bank login kabhi na karein.',
    'Apps sirf Google Play se install karein. "Mod APK" files aksar spyware chhupati hain.',
    'Phone update rakhein. Security patches wohi surakhein band karte hain jo hackers use karte hain.',
    'Click se pehle ruk jayein. Scammers jaldi ("1 ghante mein!") ka dabao dalte hain taake aap soch na saken.',
    'Khambon, parking meter par laga ya ajnabi ka bheja QR scan na karein. Us mein bura link ho sakta hai.',
    'PIN type karte waqt haath se dhaank lein aur shared device par card details save na karein.',
    'Agar galat link click ho gaya, ghabrayein nahi: kisi mehfooz device se passwords badlein aur 2FA lagayein.',
    'CNIC, passport aur OTP aapki pehchan ki chabiyan hain. Sirf official aur tasdeeq shuda jagah dein.',
    'Jo job pehle "registration fee" mange woh scam hai.',
    'Jo inaam aapne kabhi enter hi nahi kiya woh inaam nahi hota. Message delete kar dein.',
    'Dekhein kin apps ke paas accessibility, camera aur mic ka access hai. Jo zaroori nahi hata dein.',
    'Screen lock PIN ya fingerprint ka rakhein. Sirf swipe ya aasan pattern aasani se guess ho jata hai.',
    'Kisi ajnabi ke kehne par screen share ya remote apps (AnyDesk, TeamViewer) kabhi install na karein.',
    'Photos aur chats ka backup lete rahein. Phone kho jaye ya ransomware lock kar de to data mehfooz rahe.',
    'Post karte waqt ehtiyat: sali girah, school, location aur safar ka plan scammers ke kaam aata hai.',
    'Chhotay links (bit.ly, tinyurl) asli address chhupate hain. Kholne se pehle ShieldPal mein check karein.',
    'Nakli delivery message ("parcel ruka hua hai, Rs 50 dein") bohat aam hain. Parcel courier ki apni app mein track karein.',
    'Anjaan number "bank se" call kare? Phone band karein aur card par likhe number par khud call karein.',
    'Shared computer par account se logout karein aur wahan "remember me" na lagayein.',
    'Play Protect on rakhein: Play Store → profile → Play Protect → Scan apps.',
    'Scam numbers aur messages report karein. Isse doosre log bhi bachte hain.',
    'Gaming accounts nishane par hote hain. Asli email se link karein aur 2FA lagayein.',
    'Naam nahi, sender dekhein. Koi bhi khud ko "Bank Alert" naam de sakta hai.',
    'Agar offer haqeeqat se zyada achha lagey to woh jhoota hai. Guaranteed profit nahi hota.',
    'Recovery email aur phone number update rakhein taake hack hone par account wapas mil sake.',
    'Bluetooth aur hotspot istemal na ho to band rakhein.',
    'Apne walidain aur dada dadi ko OTP ka rule sikhayein. Wohi sab se zyada nishane par hote hain.',
  ];

  /// All tips in the current language. English and Roman Urdu have a long list;
  /// every other language uses the 10 tips that are translated in the app.
  static List<String> get all {
    final c = L10n.current.code;
    if (c == 'en') return en;
    if (c == 'rur') return rur;
    return [for (var i = 0; i < 10; i++) tr('tip_$i')];
  }

  static int dayIndex([DateTime? now]) {
    final d = now ?? DateTime.now();
    return d.difference(DateTime(d.year, 1, 1)).inDays + d.year * 7;
  }

  static String tipOfDay([DateTime? now]) {
    final l = all;
    return l[dayIndex(now) % l.length];
  }

  static String random(int seed) {
    final l = all;
    return l[seed.abs() % l.length];
  }
}
