enum Flavor {
  dev,
  prod,
}

class F {
  static Flavor? _appFlavor;

  static bool get appFlavorIsSet => _appFlavor != null;

  static set appFlavor(Flavor flavor) => _appFlavor = flavor;

  static Flavor get appFlavor {
    assert(_appFlavor != null, 'F.appFlavor blev læst før den var sat.');
    return _appFlavor!;
  }

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'Science Cup (Dev)';
      case Flavor.prod:
        return 'Science Cup';
    }
  }

}
