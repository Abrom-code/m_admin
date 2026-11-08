/// Encapsulates the response from the admin-reset-password Edge Function.
///
/// Security: The [temporaryPassword] is held in memory only for immediate display
/// to the authorized administrator and must never be saved to persistent storage or logs.
class ResetPasswordResult {
  const ResetPasswordResult({
    required this.success,
    required this.studentId,
    required this.studentEmail,
    required this.studentName,
    required this.temporaryPassword,
    this.message,
  });

  final bool success;
  final String studentId;
  final String studentEmail;
  final String studentName;
  final String temporaryPassword;
  final String? message;

  factory ResetPasswordResult.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResult(
      success: json['success'] == true,
      studentId: json['studentId']?.toString() ?? '',
      studentEmail: json['studentEmail']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? '',
      temporaryPassword: json['temporaryPassword']?.toString() ?? '',
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'studentId': studentId,
    'studentEmail': studentEmail,
    'studentName': studentName,
    // Note: Do not serialize temporaryPassword to disk or logs
  };
}

