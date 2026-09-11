import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:science_cup_app/core/presentation/widgets/auth_profile_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Velkommen til SCIENCEcup"),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "Om appen",
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/about'),
          ),
          AuthProfileButton(),
        ],
      ),
      body: child,
    );
  }
}

