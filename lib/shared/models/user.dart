import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String phone;       // +91XXXXXXXXXX
  final String email;       // optional — auto-filled for Google users
  final String upiVpa;      // user@okaxis (empty until set)
  final DateTime createdAt;
  final List<String> groupIds;    // denormalized for home screen
  final List<String> contactUids; // friends/contacts

  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    this.email = '',
    required this.upiVpa,
    required this.createdAt,
    required this.groupIds,
    this.contactUids = const [],
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: d['name'] as String? ?? 'Unnamed',
      phone: d['phone'] as String? ?? '',
      email: d['email'] as String? ?? '',
      upiVpa: d['upiVpa'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      groupIds: List<String>.from(d['groupIds'] as List? ?? []),
      contactUids: List<String>.from(d['contactUids'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'upiVpa': upiVpa,
        'createdAt': Timestamp.fromDate(createdAt),
        'groupIds': groupIds,
        'contactUids': contactUids,
      };

  AppUser copyWith({
    String? name,
    String? email,
    String? upiVpa,
    List<String>? groupIds,
  }) =>
      AppUser(
        uid: uid,
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        upiVpa: upiVpa ?? this.upiVpa,
        createdAt: createdAt,
        groupIds: groupIds ?? this.groupIds,
        contactUids: contactUids,
      );

  /// Deterministic avatar color index (0-7) based on name hash.
  int get avatarColorIndex => name.hashCode.abs() % 8;

  /// Initials shown when no photo available.
  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
