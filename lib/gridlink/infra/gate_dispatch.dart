import 'dart:convert';

import '../config/drift_gate_config.dart';
import '../core/link_models.dart';
import 'drift_vault.dart';
import 'pulse_agent.dart';
import 'trace_signal.dart';

/// POSTs the flat config body to the endpoint and parses the reply. A granted
/// URL is cached (with its expiry) for last-known-good returning launches.
class GateDispatch {
  GateDispatch(this._agent, this._vault);

  final PulseAgent _agent;
  final DriftVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!DriftGateConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      ndbTrace(() => '[NDB.GATE] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(DriftGateConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      ndbTrace(
        () => '[NDB.GATE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');
      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      ndbTrace(() => '[NDB.GATE] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
