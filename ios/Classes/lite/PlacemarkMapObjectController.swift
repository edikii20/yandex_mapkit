import YandexMapsMobile

class PlacemarkMapObjectController:
  NSObject,
  MapObjectController,
  YMKMapObjectTapListener,
  YMKMapObjectDragListener
{
  private let internallyControlled: Bool
  public let placemark: YMKPlacemarkMapObject
  private var consumeTapEvents: Bool = false
  public weak var controller: YandexMapController?
  public let id: String
  private var baseImage: UIImage?
  private var baseStyle: [String: Any]?
  private var baseOpacity: Float = 1
  private var shownImage: UIImage?
  private var animScale = 1.0
  private var animOpacity = 1.0
  private var animOffset = CGPoint.zero
  private var frameImage: UIImage?
  private var tracks: [PlacemarkTrack] = []
  private var transitionId: String?

  public required init(
    parent: YMKBaseMapObjectCollection,
    params: [String: Any],
    controller: YandexMapController
  ) {
    var placemark: YMKPlacemarkMapObject? = nil

    if (parent is YMKClusterizedPlacemarkCollection) {
      placemark = (parent as! YMKClusterizedPlacemarkCollection).addPlacemark()
    }

    if (parent is YMKMapObjectCollection) {
      placemark = (parent as! YMKMapObjectCollection).addPlacemark()
    }

    self.placemark = placemark!
    self.id = params["id"] as! String
    self.controller = controller
    self.internallyControlled = false

    super.init()

    placemark!.userData = self.id
    placemark!.addTapListener(with: self)
    placemark!.setDragListenerWith(self)
    update(params)
  }

  public required init(
    placemark: YMKPlacemarkMapObject,
    params: [String: Any],
    controller: YandexMapController
  ) {
    self.placemark = placemark
    self.id = params["id"] as! String
    self.controller = controller
    self.internallyControlled = true

    super.init()

    placemark.userData = self.id
    placemark.addTapListener(with: self)
    placemark.setDragListenerWith(self)
    update(params)
  }

  public func update(_ params: [String: Any]) {
    if (!internallyControlled) {
      placemark.geometry = UtilsLite.pointFromJson(params["point"] as! [String: NSNumber])
      placemark.isVisible = (params["isVisible"] as! NSNumber).boolValue
    }

    placemark.zIndex = (params["zIndex"] as! NSNumber).floatValue
    placemark.isDraggable = (params["isDraggable"] as! NSNumber).boolValue
    baseOpacity = (params["opacity"] as! NSNumber).floatValue
    placemark.direction = (params["direction"] as! NSNumber).floatValue

    setText(params["text"] as? [String: Any])
    setIcon(params["icon"] as? [String: Any])
    startTransition(params["transition"] as? [String: Any])
    applyAnimation()

    consumeTapEvents = (params["consumeTapEvents"] as! NSNumber).boolValue
  }

  public func remove() {
    controller?.placemarkAnimator.remove(self)

    if (internallyControlled) {
      return
    }

    placemark.parent.remove(with: placemark)
  }

  func onMapObjectDragStart(with mapObject: YMKMapObject) {
    controller!.mapObjectDragStart(id: id)
  }

  func onMapObjectDrag(with mapObject: YMKMapObject, point: YMKPoint) {
    controller!.mapObjectDrag(id: id, point: point)
  }

  func onMapObjectDragEnd(with mapObject: YMKMapObject) {
    controller!.mapObjectDragEnd(id: id)
  }

  func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
    controller!.mapObjectTap(id: id, point: point)

    return consumeTapEvents
  }

  private func setText(_ text: [String: Any]?) {
    if (text == nil) {
      return
    }

    placemark.setTextWithText(text!["text"] as! String, style: getTextStyle(text!["style"] as! [String: Any]))
  }

  private func setIcon(_ icon: [String: Any]?) {
    if (icon == nil) {
      return
    }

    let iconType = icon!["type"] as! String

    if (iconType == "single") {
      let style = icon!["style"] as! [String: Any]
      let image = style["image"] as! [String: Any]

      baseImage = getIconImage(image)
      baseStyle = style
    }

    if (iconType == "composite") {
      baseImage = nil
      baseStyle = nil
      shownImage = nil
      let compositeIcon = placemark.useCompositeIcon()
      let iconParts = icon!["iconParts"] as! [[String: Any]]

      for iconPart in iconParts {
        let style = iconPart["style"] as! [String: Any]
        let image = style["image"] as! [String: Any]
        let name = iconPart["name"] as! String

        compositeIcon.setIconWithName(name, image: getIconImage(image), style: getIconStyle(style))
      }
    }
  }

  private func getIconImage(_ image: [String: Any]) -> UIImage {
    let type = image["type"] as! String
    let defaultImage = UIImage()

    if (type == "fromAssetImage") {
      let assetName = controller!.pluginRegistrar.lookupKey(forAsset: image["assetName"] as! String)

      return UIImage(named: assetName) ?? defaultImage
    }

    if (type == "fromBytes") {
      let imageData = (image["rawImageData"] as! FlutterStandardTypedData).data

      return UIImage(data: imageData) ?? defaultImage
    }

    if (type == "fromCache") {
      return controller?.imageCache[image["key"] as! String] ?? defaultImage
    }

    return defaultImage
  }

  private func startTransition(_ transition: [String: Any]?) {
    guard let transition = transition, let id = transition["id"] as? String, id != transitionId else {
      return
    }

    transitionId = id
    let now = CACurrentMediaTime()

    let jsons = transition["tracks"] as? [[String: Any]] ?? []
    let properties = Set(jsons.map { ($0["property"] as! NSNumber).intValue })
    tracks.removeAll { properties.contains($0.property) }

    for json in jsons {
      let property = (json["property"] as! NSNumber).intValue
      let current = property == PlacemarkTrack.scale ? animScale : animOpacity
      let track = PlacemarkTrack(json: json, now: now, current: current) { [weak self] in
        self?.getIconImage($0 as! [String: Any]) ?? UIImage()
      }

      tracks.append(track)
    }

    if !tracks.isEmpty {
      step(now, apply: false)
      controller?.placemarkAnimator.add(self)
    }
  }

  @discardableResult
  func step(_ now: CFTimeInterval, apply: Bool = true) -> Bool {
    var seen = Set<Int>()

    for track in tracks {
      let isFirst = seen.insert(track.property).inserted
      if now < track.start && !isFirst {
        continue
      }

      let p = track.progress(now)

      switch track.property {
      case PlacemarkTrack.scale:
        animScale = track.from + (track.to - track.from) * p
      case PlacemarkTrack.opacity:
        animOpacity = track.from + (track.to - track.from) * p
      case PlacemarkTrack.offset:
        animOffset = offset(track, p)
      default:
        if track.isFinished(now) || track.frames.isEmpty {
          frameImage = nil
        } else {
          let index = Int((min(1, max(0, p)) * Double(track.frames.count - 1)).rounded())
          frameImage = track.frames[index]
        }
      }
    }

    tracks.removeAll { $0.isFinished(now) && !($0.property == PlacemarkTrack.offset && $0.toPoint != nil) }

    if apply {
      applyAnimation()
    }

    return tracks.contains { !$0.isFinished(now) }
  }

  private func offset(_ track: PlacemarkTrack, _ p: Double) -> CGPoint {
    guard let own = controller?.screenPoint(placemark.geometry) else {
      return .zero
    }

    if let from = track.fromPoint, let target = controller?.screenPoint(from) {
      return CGPoint(x: (target.x - own.x) * (1 - p), y: (target.y - own.y) * (1 - p))
    }

    if let to = track.toPoint, let target = controller?.screenPoint(to) {
      return CGPoint(x: (target.x - own.x) * p, y: (target.y - own.y) * p)
    }

    return .zero
  }

  private func applyAnimation() {
    placemark.opacity = max(0, min(1, baseOpacity * Float(animOpacity)))

    guard let image = frameImage ?? baseImage, let baseStyle = baseStyle else {
      return
    }

    let style = getIconStyle(baseStyle)
    let scale = (style.scale?.doubleValue ?? 1) * animScale
    style.scale = NSNumber(value: max(0.001, scale))

    if animOffset != .zero {
      let anchor = (style.anchor?.cgPointValue) ?? CGPoint(x: 0.5, y: 0.5)
      let width = Double(image.size.width * image.scale) * max(0.001, scale)
      let height = Double(image.size.height * image.scale) * max(0.001, scale)
      style.anchor = NSValue(cgPoint: CGPoint(
        x: Double(anchor.x) - Double(animOffset.x) / width,
        y: Double(anchor.y) - Double(animOffset.y) / height
      ))
    }

    if image !== shownImage {
      placemark.setIconWith(image, style: style)
      shownImage = image
    } else {
      placemark.setIconStyleWith(style)
    }
  }

  private func getTextStyle(_ style: [String: Any]) -> YMKTextStyle {
    let textStyle = YMKTextStyle()

    if let color = style["color"] as? NSNumber {
      textStyle.color = UtilsLite.uiColor(fromInt: color.int64Value)
    }

    if let outlineColor = style["outlineColor"] as? NSNumber {
      textStyle.outlineColor = UtilsLite.uiColor(fromInt: outlineColor.int64Value)
    }

    textStyle.size = (style["size"] as! NSNumber).floatValue
    textStyle.offset = (style["offset"] as! NSNumber).floatValue
    textStyle.offsetFromIcon = (style["offsetFromIcon"] as! NSNumber).boolValue
    textStyle.textOptional = (style["textOptional"] as! NSNumber).boolValue
    textStyle.placement = YMKTextStylePlacement.init(rawValue: (style["placement"] as! NSNumber).uintValue)!

    return textStyle
  }

  private func getIconStyle(_ style: [String: Any]) -> YMKIconStyle {
    let iconStyle = YMKIconStyle()

    if let tappableArea = style["tappableArea"] as? [String: Any] {
      iconStyle.tappableArea = UtilsLite.rectFromJson(tappableArea)
    }

    iconStyle.anchor = NSValue(cgPoint: UtilsLite.rectPointFromJson(style["anchor"] as! [String: NSNumber]))
    iconStyle.zIndex = (style["zIndex"] as! NSNumber)
    iconStyle.scale = (style["scale"] as! NSNumber)
    iconStyle.visible = (style["isVisible"] as! NSNumber)
    iconStyle.flat = (style["isFlat"] as! NSNumber)
    iconStyle.rotationType = YMKRotationType.init(
      rawValue: (style["rotationType"] as! NSNumber).uintValue
    )!.rawValue as NSNumber

    return iconStyle
  }
}
