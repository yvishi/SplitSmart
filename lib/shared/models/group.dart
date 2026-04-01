import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupType { trip, flat, couple, other }

class Group {
  final String id;
  final String name;
  final GroupType type;
  final List<String> memberUids;
  final String createdBy;
  final String? inviteCode;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Group({
    required this.id,
    required this.name,
    required this.type,
    required this.memberUids,
    required this.createdBy,
    this.inviteCode,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: d['name'] as String? ?? 'Unnamed Group',
      type: GroupType.values.firstWhere(
        (e) => e.name == d['type'],
        orElse: () => GroupType.other,
      ),
      memberUids: List<String>.from(d['memberUids'] ?? []),
      createdBy: d['createdBy'] as String? ?? '',
      inviteCode: d['inviteCode'] as String?,
      isArchived: d['isArchived'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'memberUids': memberUids,
        'createdBy': createdBy,
        'inviteCode': inviteCode,
        'isArchived': isArchived,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

