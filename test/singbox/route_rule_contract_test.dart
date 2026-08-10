import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart";

const _goldenPath = "test/singbox/testdata/route_rule_proto3.json";
const _googleProxyGoldenPath = "test/singbox/testdata/google_via_proxy_route_rule_proto3.json";
const _jsonEncoder = JsonEncoder.withIndent("  ");

RouteRule _contractRouteRule() => RouteRule(
  rules: [
    Rule(
      listOrder: 7,
      enabled: true,
      name: "complete-rule",
      outbound: Outbound.direct_with_fragment,
      ruleSets: ["geosite-google", "geoip-private"],
      packageNames: ["com.example.browser"],
      processNames: ["browser"],
      processPaths: ["/usr/bin/browser"],
      network: Network.udp,
      portRanges: ["443", "1000:2000"],
      sourcePortRanges: ["53000:53999"],
      protocols: [Protocol.tls, Protocol.http, Protocol.quic, Protocol.stun, Protocol.dns, Protocol.bittorrent],
      ipCidrs: ["203.0.113.0/24", "2001:db8::/32"],
      sourceIpCidrs: ["192.0.2.10/32"],
      domains: ["accounts.example.com"],
      domainSuffixes: ["example.net"],
      domainKeywords: ["telemetry"],
      domainRegexes: [r"^api[0-9]+\.example\.org$"],
    ),
    Rule(
      listOrder: 0,
      enabled: false,
      name: "",
      outbound: Outbound.proxy,
      network: Network.all,
      protocols: [Protocol.tls],
    ),
    Rule(name: "omitted-defaults"),
    Rule(),
  ],
);

RouteRule _validGoogleProxyRouteRule() => RouteRule(
  rules: [
    Rule(
      enabled: true,
      name: "Google via proxy",
      outbound: Outbound.proxy,
      domains: ["www.gstatic.com", "fonts.googleapis.com", "accounts.google.com", "drive.google.com"],
    ),
  ],
);

Map<String, dynamic> _routeRuleJson(RouteRule routeRule) => routeRule.toProto3Json()! as Map<String, dynamic>;

List<Map<String, dynamic>> _rules(Map<String, dynamic> routeRuleJson) =>
    (routeRuleJson["rules"]! as List<dynamic>).cast<Map<String, dynamic>>();

String _canonicalJson(Object? value) => "${_jsonEncoder.convert(value)}\n";

void main() {
  group("RouteRule ProtoJSON contract", () {
    test("matches the exhaustive wire-contract golden", () {
      final actual = _canonicalJson(_routeRuleJson(_contractRouteRule()));
      final golden = File(_goldenPath).readAsStringSync();

      expect(actual, golden);
    });

    test("matches the semantically valid Google proxy golden", () {
      final routeRuleJson = _routeRuleJson(_validGoogleProxyRouteRule());
      final actual = _canonicalJson(routeRuleJson);
      final golden = File(_googleProxyGoldenPath).readAsStringSync();

      expect(actual, golden);
      expect(_rules(routeRuleJson), [
        {
          "enabled": true,
          "name": "Google via proxy",
          "outbound": "proxy",
          "domain": ["www.gstatic.com", "fonts.googleapis.com", "accounts.google.com", "drive.google.com"],
        },
      ]);
    });

    test("uses snake_case field names and string enum names", () {
      final full = _rules(_routeRuleJson(_contractRouteRule())).first;

      expect(
        full.keys,
        orderedEquals([
          "list_order",
          "enabled",
          "name",
          "outbound",
          "rule_set",
          "package_name",
          "process_name",
          "process_path",
          "network",
          "port_range",
          "source_port_range",
          "protocol",
          "ip_cidr",
          "source_ip_cidr",
          "domain",
          "domain_suffix",
          "domain_keyword",
          "domain_regex",
        ]),
      );
      expect(full["outbound"], "direct_with_fragment");
      expect(full["network"], "udp");
      expect(full["protocol"], ["tls", "http", "quic", "stun", "dns", "bittorrent"]);
    });

    test("preserves explicit defaults and omits unset defaults", () {
      final rules = _rules(_routeRuleJson(_contractRouteRule()));

      expect(rules[1], {
        "list_order": 0,
        "enabled": false,
        "name": "",
        "outbound": "proxy",
        "network": "all",
        "protocol": ["tls"],
      });
      expect(rules[2], {"name": "omitted-defaults"});
      expect(rules[3], isEmpty);
    });

    test("omits an empty rules list", () {
      expect(_routeRuleJson(RouteRule()), isEmpty);
      expect(_routeRuleJson(RouteRule(rules: const <Rule>[])), isEmpty);
    });

    test("golden round-trips through the ProtoJSON parser", () {
      final decoded = jsonDecode(File(_goldenPath).readAsStringSync());
      final parsed = RouteRule()..mergeFromProto3Json(decoded);

      expect(_routeRuleJson(parsed), _routeRuleJson(_contractRouteRule()));
    });
  });
}
