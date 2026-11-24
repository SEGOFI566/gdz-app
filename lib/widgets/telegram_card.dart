import 'package:flutter/material.dart';

import '../download.dart';

/// Ссылка на Telegram автора, показывается над баннером APK в веб-версии.
class TelegramCard extends StatelessWidget {
  const TelegramCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF17212B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => openExternalLink('https://t.me/sygofi'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.send, color: Color(0xFF2AABEE), size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'тг @sygofi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 15,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
