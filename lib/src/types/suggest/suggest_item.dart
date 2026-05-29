part of '../../../yandex_mapkit.dart';

/// A single key/value structured property of a suggest item.
///
/// Native MapKit exposes them via `SuggestItem.properties`. For TOPONYM
/// suggests common keys are `house`, `entrance`, `building`, `block`,
/// `apartment`, `floor` etc. — the value is the concrete number/text.
class SuggestItemProperty extends Equatable {
  const SuggestItemProperty({
    required this.key,
    required this.value,
  });

  factory SuggestItemProperty._fromJson(Map<dynamic, dynamic> json) {
    return SuggestItemProperty(
      key: json['key'] as String,
      value: json['value'] as String,
    );
  }

  final String key;
  final String value;

  @override
  List<Object?> get props => <Object?>[key, value];

  @override
  bool get stringify => true;
}

/// A single suggested item.
class SuggestItem extends Equatable {
  const SuggestItem._({
    required this.title,
    required this.subtitle,
    required this.displayText,
    required this.searchText,
    required this.type,
    required this.tags,
    required this.center,
    required this.properties,
  });

  factory SuggestItem._fromJson(Map<dynamic, dynamic> json) {
    final rawProperties = json['properties'];
    return SuggestItem._(
      title: json['title'],
      subtitle: json['subtitle'],
      displayText: json['displayText'],
      searchText: json['searchText'],
      type: SuggestItemType.values[json['type']],
      tags: (json['tags'] as List<Object?>).cast<String>(),
      center: json['center'] != null ? Point._fromJson(json['center']) : null,
      properties: rawProperties is List
          ? rawProperties
              .map((e) => SuggestItemProperty._fromJson(e as Map))
              .toList()
          : const <SuggestItemProperty>[],
    );
  }

  /// Short object name.
  final String title;

  /// If type is TOPONYM returns reversed toponym hierarchy.
  /// If type is BUSINESS returns business address.
  final String? subtitle;

  /// Text to display if searchText is too technical to display.
  final String displayText;

  /// Text to search for.
  final String searchText;

  /// Suggested object type.
  final SuggestItemType type;

  /// Additional free-form data for suggest item.
  ///
  /// If type is TOPONYM, returns toponym kind (house/street/locality/...).
  /// If type is BUSINESS, returns category class (drugstores/restaurants/...).
  final List<String> tags;

  /// Position of object.
  final Point? center;

  /// Structured key/value properties of the suggest item
  /// (see [SuggestItemProperty]).
  final List<SuggestItemProperty> properties;

  @override
  List<Object?> get props => <Object?>[
    title,
    subtitle,
    searchText,
    type,
    tags,
    center,
    properties,
  ];

  @override
  bool get stringify => true;
}

enum SuggestItemType {
  unknown,
  toponym,
  business,
  transit
}
