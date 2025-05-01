class Metadata {
  final String timestamp;

  Metadata({required this.timestamp});

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}