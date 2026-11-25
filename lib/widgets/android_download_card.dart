import 'package:flutter/material.dart';

import '../download.dart';

/// Ссылка на собранный APK.
///
/// По умолчанию локальный сервер отдаёт его по `/download/gdz-app.apk`.
/// Для GitHub Pages ссылку передают при сборке:
/// `--dart-define=APK_URL=https://github.com/.../releases/download/...`.
const String kAndroidApkPath = String.fromEnvironment(
  'APK_URL',
  defaultValue: '/download/gdz-app.apk',
);

/// Баннер «Скачать для Android» для веб-версии приложения.
class AndroidDownloadCard extends StatelessWidget {
  const AndroidDownloadCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101828), Color(0xFF1D2939)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF3DDC84).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.android_rounded,
              color: Color(0xFF3DDC84),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Приложение для Android',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Скачай APK и установи на телефон — каталог работает офлайн.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => openApkDownload(kAndroidApkPath),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text('Скачать APK'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3DDC84),
                      foregroundColor: const Color(0xFF0B1220),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
