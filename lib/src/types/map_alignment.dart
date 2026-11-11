part of '../../yandex_mapkit.dart';

/// Map logo alignment.
class MapAlignment extends Equatable {
  const MapAlignment({
    required this.horizontal,
    required this.vertical,
  });

  /// Defines horizontal alignment.
  final HorizontalAlignment horizontal;

  /// Defines vertical alignment.
  final VerticalAlignment vertical;

  @override
  List<Object> get props => <Object>[
    horizontal,
    vertical,
  ];

  @override
  bool get stringify => true;

  Map<String, dynamic> toJson() {
    return {
      'horizontal': horizontal.index,
      'vertical': vertical.index
    };
  }
}

/// Map logo padding in logical pixels from the aligned edges.
class MapLogoPadding extends Equatable {
  const MapLogoPadding({
    this.horizontal = 0,
    this.vertical = 0,
  });

  /// Padding from the left or right edge.
  final double horizontal;

  /// Padding from the top or bottom edge.
  final double vertical;

  @override
  List<Object> get props => <Object>[
    horizontal,
    vertical,
  ];

  @override
  bool get stringify => true;

  Map<String, dynamic> toJson() {
    return {
      'horizontal': horizontal,
      'vertical': vertical
    };
  }
}

/// Horizontal logo alignment.
enum HorizontalAlignment {
  left,
  center,
  right
}

/// Vertical logo alignment.
enum VerticalAlignment {
  top,
  bottom
}
