import UIKit
import YandexMapsMobile

enum PlacemarkCurve {
  static func make(_ json: [String: Any]?) -> (Double) -> Double {
    let type = json?["type"] as? String ?? "linear"

    if type == "spring" {
      let damping = (json!["damping"] as! NSNumber).doubleValue
      let frequency = (json!["frequency"] as! NSNumber).doubleValue
      let decay = damping * frequency
      let settle = log(500.0) / decay
      let damped = frequency * sqrt(1 - damping * damping)

      return { t in
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        let time = t * settle
        return 1 - exp(-decay * time) * (cos(damped * time) + decay / damped * sin(damped * time))
      }
    }

    if type == "cubic" {
      let x1 = (json!["x1"] as! NSNumber).doubleValue
      let y1 = (json!["y1"] as! NSNumber).doubleValue
      let x2 = (json!["x2"] as! NSNumber).doubleValue
      let y2 = (json!["y2"] as! NSNumber).doubleValue
      let cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
      let cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by

      return { x in
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var t = x
        for _ in 0..<8 {
          let e = ((ax * t + bx) * t + cx) * t - x
          let d = (3 * ax * t + 2 * bx) * t + cx
          if abs(e) < 1e-5 || abs(d) < 1e-6 { break }
          t -= e / d
        }
        t = min(1, max(0, t))
        return ((ay * t + by) * t + cy) * t
      }
    }

    return { t in min(1, max(0, t)) }
  }
}

final class PlacemarkTrack {
  static let scale = 0
  static let opacity = 1
  static let offset = 2
  static let frames = 3

  let property: Int
  let start: CFTimeInterval
  let duration: Double
  let curve: (Double) -> Double
  var from: Double
  let to: Double
  let fromPoint: YMKPoint?
  let toPoint: YMKPoint?
  let frames: [UIImage]

  init(json: [String: Any], now: CFTimeInterval, current: Double, images: (Any) -> UIImage) {
    property = (json["property"] as! NSNumber).intValue
    duration = max(0.001, (json["duration"] as! NSNumber).doubleValue)
    start = now + (json["delay"] as! NSNumber).doubleValue
    curve = PlacemarkCurve.make(json["curve"] as? [String: Any])
    from = (json["from"] as? NSNumber)?.doubleValue ?? current
    to = (json["to"] as! NSNumber).doubleValue
    fromPoint = (json["fromPoint"] as? [String: NSNumber]).map { UtilsLite.pointFromJson($0) }
    toPoint = (json["toPoint"] as? [String: NSNumber]).map { UtilsLite.pointFromJson($0) }
    frames = (json["frames"] as? [Any] ?? []).map(images)
  }

  func progress(_ now: CFTimeInterval) -> Double {
    if now <= start { return 0 }
    return curve(min(1, (now - start) / duration))
  }

  func isFinished(_ now: CFTimeInterval) -> Bool {
    return now >= start + duration
  }
}

final class PlacemarkAnimator: NSObject {
  private var link: CADisplayLink?
  private var active: [ObjectIdentifier: PlacemarkMapObjectController] = [:]

  func add(_ controller: PlacemarkMapObjectController) {
    active[ObjectIdentifier(controller)] = controller

    if link == nil {
      let link = CADisplayLink(target: self, selector: #selector(tick))
      link.add(to: .main, forMode: .common)
      self.link = link
    }
  }

  func remove(_ controller: PlacemarkMapObjectController) {
    active.removeValue(forKey: ObjectIdentifier(controller))
    stopIfIdle()
  }

  func stop() {
    active.removeAll()
    stopIfIdle()
  }

  @objc private func tick() {
    let now = CACurrentMediaTime()

    for (key, controller) in active {
      if !controller.step(now) {
        active.removeValue(forKey: key)
      }
    }

    stopIfIdle()
  }

  private func stopIfIdle() {
    if active.isEmpty {
      link?.invalidate()
      link = nil
    }
  }
}
