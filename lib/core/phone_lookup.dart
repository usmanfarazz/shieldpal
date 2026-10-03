import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// What can honestly be learned from a phone number without spying on anyone:
/// country, number type, mobile network (from the prefix) and warning signs.
/// The owner's name and live location are private and are NOT shown -
/// only the police / telecom operator can trace those legally.
class NumberReport {
  final String input;
  final bool valid;
  final String? international;
  final String? countryIso;
  final String? countryCode;
  final String? type; // localisation key
  final String? network;
  final List<String> warnings; // localisation keys
  final int risk; // 0..100
  final bool reportedByYou;

  NumberReport({
    required this.input,
    required this.valid,
    this.international,
    this.countryIso,
    this.countryCode,
    this.type,
    this.network,
    this.warnings = const [],
    this.risk = 0,
    this.reportedByYou = false,
  });
}

class PhoneLookup {
  // Original network by prefix. Pakistan allows number porting, so this is
  // the network the number was first issued on.
  static const Map<String, String> _pkPrefixes = {
    '300': 'Jazz', '301': 'Jazz', '302': 'Jazz', '303': 'Jazz', '304': 'Jazz',
    '305': 'Jazz', '306': 'Jazz', '307': 'Jazz', '308': 'Jazz', '309': 'Jazz',
    '320': 'Jazz', '321': 'Jazz', '322': 'Jazz', '323': 'Jazz', '324': 'Jazz', '325': 'Jazz',
    '310': 'Zong', '311': 'Zong', '312': 'Zong', '313': 'Zong', '314': 'Zong',
    '315': 'Zong', '316': 'Zong', '317': 'Zong', '318': 'Zong', '319': 'Zong',
    '330': 'Ufone', '331': 'Ufone', '332': 'Ufone', '333': 'Ufone', '334': 'Ufone',
    '335': 'Ufone', '336': 'Ufone', '337': 'Ufone', '338': 'Ufone', '339': 'Ufone',
    '340': 'Telenor', '341': 'Telenor', '342': 'Telenor', '343': 'Telenor', '344': 'Telenor',
    '345': 'Telenor', '346': 'Telenor', '347': 'Telenor', '348': 'Telenor', '349': 'Telenor',
    '355': 'SCO',
  };

  // Countries frequently seen in "wangiri" (missed-call) and premium-rate fraud.
  static const Set<String> _wangiriCountries = {
    'TN', 'MR', 'ML', 'GN', 'CI', 'BJ', 'BF', 'SN', 'GM', 'GW', 'SL', 'LR', 'TG',
    'CF', 'TD', 'CG', 'CD', 'GA', 'CM', 'ER', 'SO', 'ZW', 'MG', 'KM', 'SC', 'TV',
    'NR', 'KI', 'SB', 'VU', 'TO', 'WS', 'CK', 'NU', 'PG', 'CU', 'LV', 'BY', 'MD',
    'GL', 'FO', 'AQ', 'SH', 'IO',
  };

  static NumberReport check(String raw, {required IsoCode home, Set<String> reported = const {}}) {
    final cleaned = raw.trim();
    PhoneNumber? p;
    try {
      p = PhoneNumber.parse(cleaned, callerCountry: home);
    } catch (_) {
      p = null;
    }
    if (p == null || p.nsn.isEmpty) {
      return NumberReport(input: raw, valid: false, warnings: const ['w_invalid'], risk: 40);
    }
    final valid = p.isValid();
    String? type;
    for (final t in [
      PhoneNumberType.mobile,
      PhoneNumberType.fixedLine,
      PhoneNumberType.tollFree,
      PhoneNumberType.premiumRate,
      PhoneNumberType.voip,
      PhoneNumberType.sharedCost,
      PhoneNumberType.personalNumber,
      PhoneNumberType.uan,
    ]) {
      if (p.isValid(type: t)) {
        type = 't_${t.name}';
        break;
      }
    }
    final warnings = <String>[];
    var risk = 0;
    if (!valid) {
      warnings.add('w_invalid');
      risk += 40;
    }
    if (type == 't_premiumRate') {
      warnings.add('w_premium');
      risk += 50;
    }
    if (type == 't_voip') {
      warnings.add('w_voip');
      risk += 20;
    }
    if (p.isoCode != home) {
      warnings.add('w_foreign');
      risk += 10;
    }
    if (_wangiriCountries.contains(p.isoCode.name)) {
      warnings.add('w_wangiri');
      risk += 30;
    }
    if (RegExp(r'^\d{3,6}$').hasMatch(cleaned)) {
      warnings.add('w_short_code');
    }
    String? network;
    if (p.isoCode == IsoCode.PK && p.nsn.length >= 3) {
      network = _pkPrefixes[p.nsn.substring(0, 3)];
    }
    final reportedByYou = reported.contains(p.international);
    if (reportedByYou) {
      warnings.add('w_reported');
      risk += 60;
    }
    return NumberReport(
      input: raw,
      valid: valid,
      international: p.international,
      countryIso: p.isoCode.name,
      countryCode: p.countryCode,
      type: type,
      network: network,
      warnings: warnings,
      risk: risk.clamp(0, 100),
      reportedByYou: reportedByYou,
    );
  }

  static String flag(String iso) {
    if (iso.length != 2) return '🌐';
    final a = iso.toUpperCase().codeUnitAt(0) - 65 + 0x1F1E6;
    final b = iso.toUpperCase().codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes([a, b]);
  }
}
