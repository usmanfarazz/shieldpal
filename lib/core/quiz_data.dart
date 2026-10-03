/// "Scam or Safe?" game cards. The message samples are realistic examples
/// (some in English, some in Roman Urdu, like real inboxes); the
/// explanation is a translated key so every player understands why.
class QuizCard {
  final String sender;
  final String message;
  final bool isScam;
  final String why; // localisation key
  const QuizCard(this.sender, this.message, this.isScam, this.why);
}

const List<QuizCard> quizCards = [
  QuizCard('+1 (555) 019-2231', 'Garena: Claim 5000 FREE diamonds before midnight! Login: ff-garena-event.xyz', true, 'qx_fake_domain'),
  QuizCard('Garena', 'Your top-up of 310 diamonds was successful. Order ID FF8822931.', false, 'qx_receipt'),
  QuizCard('Unknown', 'Bro is link pe login karo, free elite pass mil raha hai 😍 freefire-pass.top', true, 'qx_fake_domain'),
  QuizCard('8171', 'BISP: Aap ke 25,000 rupay aa gaye hain. Wusooli ke liye apna CNIC aur OTP bhejein.', true, 'qx_otp'),
  QuizCard('HBL', 'Your OTP is 551203 for login. Never share this code with anyone, including HBL staff.', false, 'qx_real_otp'),
  QuizCard('+92 341 0000000', 'Galti se aapke number par 6 digit code chala gaya, please woh mujhe bhej dein.', true, 'qx_code_back'),
  QuizCard('Ammi', 'Beta khana kha liya? Raat ko jaldi ghar aa jana.', false, 'qx_normal'),
  QuizCard('+44 7700 900123', 'Mom, this is my new number, my phone broke. Can you send 300 urgently? Don\'t tell dad.', true, 'qx_family_imp'),
  QuizCard('Daraz', 'Your order #D-482913 has been shipped and will arrive on Thursday.', false, 'qx_receipt'),
  QuizCard('TCS', 'Your parcel is on hold. Pay Rs 50 customs fee here: tcs-delivery-pk.online/pay', true, 'qx_fake_domain'),
  QuizCard('Instagram', 'Someone tried to log in from a new device. If this wasn\'t you, secure your account in the Instagram app.', false, 'qx_inapp'),
  QuizCard('Meta Support', 'Your page violates copyright and will be deleted in 24h. Appeal: meta-appeal-center.com', true, 'qx_threat'),
  QuizCard('Friend', 'Free robux!!! roblox-free-robux.site just type username + password 🤑', true, 'qx_password'),
  QuizCard('School', 'Reminder: parent teacher meeting on Saturday 10 am in the main hall.', false, 'qx_normal'),
  QuizCard('JazzCash', 'Rs 1,500 received from Ahmed Ali. Available balance Rs 3,240.', false, 'qx_receipt'),
  QuizCard('+92 300 7654321', 'Mubarak ho! Jeeto Pakistan mein aapka 50,000 ka inaam nikla hai. Fee 2000 jama karwa kar inaam lein.', true, 'qx_prize'),
  QuizCard('HR Team', 'Earn 5000 daily from home by liking videos. Registration fee only 1500 via Easypaisa.', true, 'qx_job'),
  QuizCard('Google', 'Security alert: new sign-in on Windows. Check activity in your Google Account.', false, 'qx_inapp'),
  QuizCard('Unknown', 'Your Apple ID is locked. Unlock now at apple-id-verify-support.com', true, 'qx_fake_domain'),
  QuizCard('Bank', 'Main bank se bol raha hun, aapka card block ho gaya hai. Card ke peechay wale 3 number batayein.', true, 'qx_cvv'),
  QuizCard('Cousin', 'Kal shaadi mein zaroor aana, location: https://maps.google.com/?q=lahore', false, 'qx_known_site'),
  QuizCard('Netflix', 'Payment failed. Update card within 12 hours: netflix-billing-help.club', true, 'qx_fake_domain'),
  QuizCard('Steam friend', 'Hey I accidentally reported you, talk to this admin on Discord to fix your account.', true, 'qx_social'),
  QuizCard('WhatsApp', 'Your WhatsApp code: 123-456. Don\'t share this code with others.', false, 'qx_real_otp'),
  QuizCard('+880 1700 000000', 'Congratulations! You won iPhone 17 Pro. Pay delivery charges to receive.', true, 'qx_prize'),
  QuizCard('Crypto Club', 'Invest \$100 and get \$1000 in 7 days. Guaranteed profit!', true, 'qx_too_good'),
  QuizCard('Teacher', 'Assignment deadline extended to Monday. Submit on the portal.', false, 'qx_normal'),
  QuizCard('PTA', 'Your SIM will be blocked in 2 hours. Press 1 and give your CNIC to verify.', true, 'qx_threat'),
  QuizCard('Unknown', 'Hi, is this the right number for Sara? Sorry, wrong number 🙏 By the way I trade crypto…', true, 'qx_social'),
  QuizCard('YouTube', 'Your video got 1,000 views! See analytics in YouTube Studio.', false, 'qx_inapp'),
  QuizCard('Scan me', 'QR code on a parking meter: pay-parking-city.top', true, 'qx_quishing'),
  QuizCard('Electric co.', 'Bijli ka bill bakaya hai, aaj raat connection kat diya jayega. Is number par call karein.', true, 'qx_threat'),
  QuizCard('Dad', 'Running late, start dinner without me.', false, 'qx_normal'),
  QuizCard('Microsoft', 'Your PC is infected! Call Microsoft support now: +1 800 000 0000', true, 'qx_tech_support'),
  QuizCard('Binance', 'Airdrop: connect wallet to claim 500 USDT: binance-airdrop.live', true, 'qx_fake_domain'),
  QuizCard('Uber', 'Your Uber code is 4821. Never share this code.', false, 'qx_real_otp'),
  QuizCard('Unknown', 'Mod APK Free Fire unlimited diamonds download: ffmod.apk-download.xyz/ff.apk', true, 'qx_apk'),
  QuizCard('Class group', 'Notes for chapter 5 uploaded on the school drive.', false, 'qx_normal'),
  QuizCard('Recruiter', 'Visa guaranteed for Dubai! Send passport copy and 50,000 advance today.', true, 'qx_job'),
  QuizCard('PayPal', 'You received \$25.00 from John. View in the PayPal app.', false, 'qx_inapp'),
];
