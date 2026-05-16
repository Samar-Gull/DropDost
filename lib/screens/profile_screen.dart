import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/database_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final user = authService.currentUser;
    final photoBytes = _decodePhoto(user?.profilePhotoBase64);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: user == null
                ? null
                : () => _showEditProfileDialog(context, authService, user),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor,
              backgroundImage: photoBytes == null
                  ? null
                  : MemoryImage(photoBytes),
              child: photoBytes == null
                  ? Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              user?.name ?? 'User',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user?.userType.toUpperCase() ?? '',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
            _buildInfoCard(Icons.email_outlined, 'Email', user?.email ?? ''),
            const SizedBox(height: 12),
            _buildInfoCard(Icons.phone_outlined, 'Phone', user?.phone ?? ''),
            const SizedBox(height: 12),
            _buildInfoCard(
              Icons.calendar_today_outlined,
              'Member Since',
              user?.createdAt.toString().substring(0, 10) ?? '',
            ),
            if (user?.userType == 'rider') ...[
              const SizedBox(height: 24),
              _buildRiderFeedback(db, user!.uid),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('LOGOUT'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AuthService authService,
    UserModel user,
  ) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    String? selectedPhoto = user.profilePhotoBase64;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final previewBytes = _decodePhoto(selectedPhoto);

          Future<void> pickPhoto() async {
            final image = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 256,
              maxHeight: 256,
              imageQuality: 70,
            );
            if (image == null) return;

            final bytes = await image.readAsBytes();
            setDialogState(() => selectedPhoto = base64Encode(bytes));
          }

          Future<void> saveProfile() async {
            final phone = phoneController.text.trim();
            if (nameController.text.trim().isEmpty ||
                !RegExp(r'^\d{11}$').hasMatch(phone)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a name and exactly 11 phone digits'),
                ),
              );
              return;
            }

            setDialogState(() => isSaving = true);
            final error = await authService.updateProfile(
              name: nameController.text.trim(),
              phone: phone,
              profilePhotoBase64: selectedPhoto,
            );

            if (!context.mounted) return;
            setDialogState(() => isSaving = false);

            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error), backgroundColor: Colors.red),
              );
              return;
            }

            Navigator.pop(dialogContext);
          }

          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage: previewBytes == null
                        ? null
                        : MemoryImage(previewBytes),
                    child: previewBytes == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 36,
                          )
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: pickPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Update Photo'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    phoneController.dispose();
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2ECC71)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiderFeedback(DatabaseService db, String riderId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.getRiderFeedback(riderId),
      builder: (context, snapshot) {
        final feedback = snapshot.data ?? [];
        if (feedback.isEmpty) {
          return const SizedBox.shrink();
        }

        final avg =
            feedback.fold<num>(
              0,
              (sum, item) => sum + ((item['rating'] ?? 0) as num),
            ) /
            feedback.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rider Feedback (${avg.toStringAsFixed(1)} / 5)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...feedback
                .take(3)
                .map(
                  (item) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.star, color: Colors.orange),
                    title: Text('${item['rating']} / 5'),
                    subtitle: Text(item['comment'] ?? ''),
                  ),
                ),
          ],
        );
      },
    );
  }

  Uint8List? _decodePhoto(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}
