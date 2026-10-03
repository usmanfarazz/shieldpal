/// DNS servers Shield VPN can use. Keep ids in sync with ShieldVpnService.kt.
class VpnServer {
  final String id;
  final String emoji;
  final String ip; // shown to the user
  const VpnServer(this.id, this.emoji, this.ip);
  String get nameKey => 'vs_$id';
  String get descKey => 'vsd_$id';
}

const List<VpnServer> vpnServers = [
  VpnServer('cf_security', '🛡️', '1.1.1.2'),
  VpnServer('cf_family', '👨‍👩‍👧', '1.1.1.3'),
  VpnServer('cf_fast', '⚡', '1.1.1.1'),
  VpnServer('google', '🔎', '8.8.8.8'),
  VpnServer('quad9', '🧱', '9.9.9.9'),
  VpnServer('adguard', '🚫', '94.140.14.14'),
  VpnServer('opendns', '🌍', '208.67.222.222'),
];

VpnServer vpnServerFor(String id) => vpnServers.firstWhere((s) => s.id == id, orElse: () => vpnServers.first);
