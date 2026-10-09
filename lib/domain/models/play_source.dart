/// Where a play came from. Stored in `playevent.source`; rows written before
/// schema v2 have no source and parse to null.
enum PlaySource {
  manual('manual'),
  shuffle('shuffle'),
  radio('radio'),
  queued('queued'),
  linear('linear');

  const PlaySource(this.dbValue);

  final String dbValue;

  static PlaySource? parse(String? value) {
    if (value == null) return null;
    for (final s in PlaySource.values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}
