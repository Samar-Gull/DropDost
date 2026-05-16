import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/database_service.dart';

class NotificationButton extends StatelessWidget {
  final String? userId;

  const NotificationButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final id = userId;
    if (id == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: null,
      );
    }

    final db = Provider.of<DatabaseService>(context, listen: false);

    return StreamBuilder<int>(
      stream: db.getUnreadNotificationCount(id),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return IconButton(
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count.toString()),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () async {
            await db.ensureMonthlySurveyNotification(id);
            if (context.mounted) _showNotifications(context, db, id);
          },
        );
      },
    );
  }

  Future<void> _showNotifications(
    BuildContext context,
    DatabaseService db,
    String userId,
  ) async {
    await db.markNotificationsRead(userId);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.getUserNotifications(userId),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const SizedBox(
              height: 220,
              child: Center(child: Text('No notifications')),
            );
          }

          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSurvey = item['type'] == 'monthly_feedback';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(item['title'] ?? ''),
                      subtitle: Text(item['body'] ?? ''),
                    ),
                    if (isSurvey)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await db.skipMonthlyFeedback(
                                    userId,
                                    item['id'],
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: const Text('Skip'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showMonthlyFeedbackDialog(
                                  context,
                                  db,
                                  userId,
                                  item['id'],
                                ),
                                child: const Text('Answer'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMonthlyFeedbackDialog(
    BuildContext context,
    DatabaseService db,
    String userId,
    String notificationId,
  ) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Monthly Feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Your feedback'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await db.submitMonthlyFeedback(
                userId: userId,
                notificationId: notificationId,
                comment: controller.text.trim(),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    controller.dispose();
  }
}
