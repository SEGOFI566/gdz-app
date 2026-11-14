import 'package:flutter/material.dart';

import '../theme.dart';

class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.onTap,
    this.hint = 'Номер задания, тема или учебник',
  });

  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E4EF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: kMuted, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: kMuted),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPaper,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'поиск',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
