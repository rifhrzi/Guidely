import 'package:flutter/material.dart';
import 'package:navmate/l10n/app_localizations.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.help)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.helpBody),
      ),
    );
  }
}
