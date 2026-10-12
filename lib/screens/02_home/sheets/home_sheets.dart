import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/community_models.dart';
import '../../../services/community_service.dart';

void showUpdateSheet(LocalUpdate update) {
  Get.bottomSheet(
    UpdateDetailsSheet(update: update),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class AreaSelectionSheet extends StatefulWidget {
  const AreaSelectionSheet({super.key});

  @override
  State<AreaSelectionSheet> createState() => _AreaSelectionSheetState();
}

class _AreaSelectionSheetState extends State<AreaSelectionSheet> {
  final community = Get.find<CommunityService>();
  final input = TextEditingController();

  String? validationMessage;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> select(String area) async {
    FocusScope.of(context).unfocus();

    final success = await community.selectArea(area);

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> saveCustomArea() async {
    final value = input.text.trim();

    if (value.isEmpty || value.length > 60) {
      setState(() {
        validationMessage = '১–৬০ অক্ষরের এলাকা লিখুন।';
      });
      return;
    }

    await select(value);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Obx(() {
              final areas = {
                'সব এলাকা',
                ...community.availableAreas,
                community.selectedArea.value,
              }.toList();

              return ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  22,
                  12,
                  22,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5DDD4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'আপনার এলাকা',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'এলাকা নির্বাচন optional। GPS প্রয়োজন নেই।',
                    style: TextStyle(
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: input,
                    maxLength: 60,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => saveCustomArea(),
                    decoration: InputDecoration(
                      hintText: 'নিজের ইউনিয়ন, বাজার বা স্ট্যান্ড লিখুন',
                      errorText: validationMessage,
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: community.saving.value
                        ? null
                        : saveCustomArea,
                    child: const Text('এই এলাকা নির্বাচন করুন'),
                  ),
                  const SizedBox(height: 20),
                  for (final area in areas)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(area),
                      leading: Icon(
                        area == 'সব এলাকা'
                            ? Icons.public_rounded
                            : Icons.place_outlined,
                      ),
                      trailing: community.selectedArea.value == area
                          ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.pine,
                      )
                          : null,
                      onTap: community.saving.value
                          ? null
                          : () => select(area),
                    ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

class UpdateDetailsSheet extends StatelessWidget {
  const UpdateDetailsSheet({
    super.key,
    required this.update,
  });

  final LocalUpdate update;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      update.label.isEmpty
                          ? 'স্থানীয় ঘোষণা'
                          : update.label,
                      style: const TextStyle(
                        color: AppColors.pine,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'বন্ধ করুন',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                update.title,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (update.publishedAt != null)
                Text(
                  dateText(update.publishedAt),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 22),
              SelectableText(
                update.body,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.8,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}