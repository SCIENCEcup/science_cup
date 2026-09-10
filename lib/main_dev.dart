import 'package:science_cup_app/flavors.dart';
import 'package:science_cup_app/main.dart' as app;

Future<void> main() async {
  F.appFlavor = Flavor.dev;
  await app.main();
}
