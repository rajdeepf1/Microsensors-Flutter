class NotificationModel {
  final int notificationId;
  final int? userId;
  final int? orderId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    this.userId,
    this.orderId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notificationId'],
      userId: json['userId'],
      orderId: json['orderId'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  String get formattedCreatedAt {
    final dt = createdAt.toLocal();
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }
}

class NotificationPageResult {
  final List<NotificationModel> items;
  final int? total;

  NotificationPageResult({required this.items, this.total});
}