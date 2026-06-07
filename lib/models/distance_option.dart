class DistanceOption {
  const DistanceOption({required this.label, required this.rateBaht});

  final String label;
  final int rateBaht;

  int totalFor(int rounds) => rounds * rateBaht;
}
