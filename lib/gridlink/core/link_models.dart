/// Persisted routing decision for a given install.
enum DriftLane {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    DriftLane.native => 'native',
    DriftLane.portal => 'portal',
    DriftLane.undecided => 'undecided',
  };

  static DriftLane parse(String? value) => switch (value) {
    'portal' || 'web' => DriftLane.portal,
    'native' || 'game' => DriftLane.native,
    _ => DriftLane.undecided,
  };
}

/// Parsed config-endpoint response.
class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

/// Where the router decided to send the user.
sealed class LaneTarget {
  const LaneTarget();
}

final class NativeLane extends LaneTarget {
  const NativeLane();
}

final class PortalLane extends LaneTarget {
  const PortalLane(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class DarkLane extends LaneTarget {
  const DarkLane({required this.returnToNative});

  final bool returnToNative;
}
