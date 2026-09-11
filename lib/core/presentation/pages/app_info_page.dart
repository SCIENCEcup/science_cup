import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInfoPage extends StatefulWidget {
  const AppInfoPage({super.key});

  @override
  State<AppInfoPage> createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> {
  static final Uri _feedbackUrl = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSeRaOpJT79Ft0Ro-nj9Xp9jHp1XUhjrTHN8di-7Of2Zhlx11g/viewform?usp=dialog',
  );

  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Om appen')),
      body: FutureBuilder<PackageInfo>(
        future: _packageInfoFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final info = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      size: 56.0,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12.0),
                    Text(info.appName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4.0),
                    Text(
                      'Version ${info.version} (build ${info.buildNumber})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40.0),
              FilledButton.icon(
                onPressed: () => launchUrl(
                  _feedbackUrl,
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.feedback_outlined),
                label: const Text('Send feedback'),
              ),
            ],
          );
        },
      ),
    );
  }
}
