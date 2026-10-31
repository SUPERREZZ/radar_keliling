class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final String role; // "buyer" | "merchant" | "admin"
  final bool emailVerified;

  bool get isBuyer => role == 'buyer';
  bool get isMerchant => role == 'merchant';
  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        emailVerified: json['email_verified'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'email_verified': emailVerified,
      };
}
