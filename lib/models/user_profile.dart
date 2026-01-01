import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String email;
  final String displayName;
  final String photoURL;
  final DateTime? createdAt;

  UserProfile({
    required this.email,
    this.displayName = '',
    this.photoURL = '',
    this.createdAt,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    return UserProfile(
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}