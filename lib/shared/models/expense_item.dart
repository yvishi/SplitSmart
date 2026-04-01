class ExpenseItem {
  final String name;
  final double price;
  final List<String> assignedUids;
  final double ocrConfidence;

  const ExpenseItem({
    required this.name,
    required this.price,
    this.assignedUids = const [],
    this.ocrConfidence = 1.0,
  });

  bool get isLowConfidence => ocrConfidence < 0.7;

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      name: map['name'] as String? ?? 'Unnamed Item',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      assignedUids: List<String>.from(map['assignedUids'] ?? []),
      ocrConfidence: (map['ocrConfidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'assignedUids': assignedUids,
        'ocrConfidence': ocrConfidence,
      };

  ExpenseItem copyWith({
    String? name,
    double? price,
    List<String>? assignedUids,
    double? ocrConfidence,
  }) {
    return ExpenseItem(
      name: name ?? this.name,
      price: price ?? this.price,
      assignedUids: assignedUids ?? this.assignedUids,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
    );
  }
}

