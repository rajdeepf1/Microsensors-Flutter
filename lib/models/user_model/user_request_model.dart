class UpdateUserRequest {
  final int userId; // <- not in JSON body, but passed in the path
  final String? userName;
  final String? email;
  final String? phoneNumber;
  final String? oldPassword;
  final String? newPassword;

  UpdateUserRequest({
    required this.userId,
    this.userName,
    this.email,
    this.phoneNumber,
    this.oldPassword,
    this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      "username": userName,
      "email": email,
      "mobileNumber": phoneNumber,
      "oldPassword": oldPassword,
      "newPassword": newPassword,
    }..removeWhere((key, value) => value == null || (value is String && value.isEmpty));
  }
}
