part of '../../yandex_mapkit.dart';

class MapLoadStatistics extends Equatable {
  const MapLoadStatistics({
    required this.curZoomGeometryLoaded,
    required this.curZoomPlacemarksLoaded,
    required this.curZoomLabelsLoaded,
    required this.delayedGeometryLoaded,
    required this.curZoomModelsLoaded,
    required this.fullyLoaded,
    required this.fullyAppeared,
    required this.renderObjectCount,
    required this.tileMemoryUsage,
  });

  final Duration curZoomGeometryLoaded;
  final Duration curZoomPlacemarksLoaded;
  final Duration curZoomLabelsLoaded;
  final Duration delayedGeometryLoaded;
  final Duration curZoomModelsLoaded;
  final Duration fullyLoaded;
  final Duration fullyAppeared;
  final int renderObjectCount;
  final int tileMemoryUsage;

  @override
  List<Object> get props => <Object>[
    curZoomGeometryLoaded,
    curZoomPlacemarksLoaded,
    curZoomLabelsLoaded,
    delayedGeometryLoaded,
    curZoomModelsLoaded,
    fullyLoaded,
    fullyAppeared,
    renderObjectCount,
    tileMemoryUsage,
  ];

  @override
  bool get stringify => true;

  factory MapLoadStatistics._fromJson(Map<dynamic, dynamic> json) {
    Duration duration(String key) =>
        Duration(milliseconds: (json[key] as num).toInt());

    return MapLoadStatistics(
      curZoomGeometryLoaded: duration('curZoomGeometryLoaded'),
      curZoomPlacemarksLoaded: duration('curZoomPlacemarksLoaded'),
      curZoomLabelsLoaded: duration('curZoomLabelsLoaded'),
      delayedGeometryLoaded: duration('delayedGeometryLoaded'),
      curZoomModelsLoaded: duration('curZoomModelsLoaded'),
      fullyLoaded: duration('fullyLoaded'),
      fullyAppeared: duration('fullyAppeared'),
      renderObjectCount: (json['renderObjectCount'] as num).toInt(),
      tileMemoryUsage: (json['tileMemoryUsage'] as num).toInt(),
    );
  }
}
