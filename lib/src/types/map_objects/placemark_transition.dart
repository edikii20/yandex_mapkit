part of '../../../yandex_mapkit.dart';

/// Property of a [PlacemarkMapObject] animated by a [PlacemarkTrack].
enum PlacemarkTrackProperty {
  /// Icon scale multiplier, relative to the icon anchor.
  scale,

  /// Opacity multiplier.
  opacity,

  /// Screen offset towards [PlacemarkTrack.fromPoint] or [PlacemarkTrack.toPoint].
  offset,

  /// Icon image switched over [PlacemarkTrack.frames].
  frames
}

/// Timing curve of a [PlacemarkTrack].
class PlacemarkCurve extends Equatable {
  final Map<String, dynamic> _json;

  const PlacemarkCurve._(this._json);

  /// Linear curve.
  static const linear = PlacemarkCurve._({'type': 'linear'});

  /// Damped spring stretched over the track duration.
  factory PlacemarkCurve.spring({required double damping, required double frequency}) {
    return PlacemarkCurve._({'type': 'spring', 'damping': damping, 'frequency': frequency});
  }

  /// Cubic bezier curve.
  factory PlacemarkCurve.cubic(double x1, double y1, double x2, double y2) {
    return PlacemarkCurve._({'type': 'cubic', 'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2});
  }

  Map<String, dynamic> toJson() => _json;

  @override
  List<Object> get props => <Object>[_json];
}

/// Single animated property of a [PlacemarkTransition].
class PlacemarkTrack extends Equatable {
  const PlacemarkTrack({
    required this.property,
    required this.duration,
    this.delay = Duration.zero,
    this.curve = PlacemarkCurve.linear,
    this.from,
    this.to = 1,
    this.fromPoint,
    this.toPoint,
    this.frames = const []
  });

  final PlacemarkTrackProperty property;
  final Duration duration;
  final Duration delay;
  final PlacemarkCurve curve;

  /// Start value for scale and opacity. Null starts from the current animated value.
  final double? from;

  /// End value for scale and opacity.
  final double to;

  /// Offset track starts displaced to the screen position of this point.
  final Point? fromPoint;

  /// Offset track ends displaced to the screen position of this point.
  final Point? toPoint;

  /// Images for frames track; the curve value picks the frame.
  final List<BitmapDescriptor> frames;

  Map<String, dynamic> toJson() {
    return {
      'property': property.index,
      'duration': duration.inMicroseconds / 1000000,
      'delay': delay.inMicroseconds / 1000000,
      'curve': curve.toJson(),
      'from': from,
      'to': to,
      'fromPoint': fromPoint?.toJson(),
      'toPoint': toPoint?.toJson(),
      'frames': frames.map((e) => e.toJson()).toList()
    };
  }

  @override
  List<Object?> get props => <Object?>[property, duration, delay, curve, from, to, fromPoint, toPoint, frames];
}

/// Animation played once by the platform when a placemark with a new [id] is added or updated.
class PlacemarkTransition extends Equatable {
  const PlacemarkTransition({
    required this.id,
    required this.tracks
  });

  final String id;
  final List<PlacemarkTrack> tracks;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tracks': tracks.map((e) => e.toJson()).toList()
    };
  }

  @override
  List<Object> get props => <Object>[id];
}
