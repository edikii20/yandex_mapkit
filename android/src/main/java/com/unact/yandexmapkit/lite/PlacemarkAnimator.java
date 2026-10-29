package com.unact.yandexmapkit.lite;

import android.view.Choreographer;

import com.yandex.mapkit.geometry.Point;
import com.yandex.runtime.image.ImageProvider;

import java.util.ArrayList;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;

public class PlacemarkAnimator implements Choreographer.FrameCallback {
  public static final int SCALE = 0;
  public static final int OPACITY = 1;
  public static final int OFFSET = 2;
  public static final int FRAMES = 3;

  public interface Curve {
    double apply(double t);
  }

  public interface ImageResolver {
    ImageProvider resolve(Map<String, Object> image);
  }

  public static class Track {
    public final int property;
    public final double start;
    public final double duration;
    public final Curve curve;
    public final double from;
    public final double to;
    public final Point fromPoint;
    public final Point toPoint;
    public final List<ImageProvider> frames = new ArrayList<>();

    @SuppressWarnings({"unchecked", "ConstantConditions"})
    public Track(Map<String, Object> json, double now, double current, ImageResolver images) {
      property = ((Number) json.get("property")).intValue();
      duration = Math.max(0.001, ((Number) json.get("duration")).doubleValue());
      start = now + ((Number) json.get("delay")).doubleValue();
      curve = curve((Map<String, Object>) json.get("curve"));
      from = json.get("from") != null ? ((Number) json.get("from")).doubleValue() : current;
      to = ((Number) json.get("to")).doubleValue();
      fromPoint = json.get("fromPoint") != null ? UtilsLite.pointFromJson((Map<String, Object>) json.get("fromPoint")) : null;
      toPoint = json.get("toPoint") != null ? UtilsLite.pointFromJson((Map<String, Object>) json.get("toPoint")) : null;

      List<Object> frameList = (List<Object>) json.get("frames");
      if (frameList != null) {
        for (Object frame : frameList) {
          frames.add(images.resolve((Map<String, Object>) frame));
        }
      }
    }

    public double progress(double now) {
      if (now <= start) return 0;
      return curve.apply(Math.min(1, (now - start) / duration));
    }

    public boolean isFinished(double now) {
      return now >= start + duration;
    }
  }

  @SuppressWarnings({"ConstantConditions"})
  public static Curve curve(Map<String, Object> json) {
    String type = json != null ? (String) json.get("type") : "linear";

    if ("spring".equals(type)) {
      final double damping = ((Number) json.get("damping")).doubleValue();
      final double frequency = ((Number) json.get("frequency")).doubleValue();
      final double decay = damping * frequency;
      final double settle = Math.log(500.0) / decay;
      final double damped = frequency * Math.sqrt(1 - damping * damping);

      return t -> {
        if (t <= 0) return 0;
        if (t >= 1) return 1;
        double time = t * settle;
        return 1 - Math.exp(-decay * time) * (Math.cos(damped * time) + decay / damped * Math.sin(damped * time));
      };
    }

    if ("cubic".equals(type)) {
      final double x1 = ((Number) json.get("x1")).doubleValue();
      final double y1 = ((Number) json.get("y1")).doubleValue();
      final double x2 = ((Number) json.get("x2")).doubleValue();
      final double y2 = ((Number) json.get("y2")).doubleValue();
      final double cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
      final double cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;

      return x -> {
        if (x <= 0) return 0;
        if (x >= 1) return 1;
        double t = x;
        for (int i = 0; i < 8; i++) {
          double e = ((ax * t + bx) * t + cx) * t - x;
          double d = (3 * ax * t + 2 * bx) * t + cx;
          if (Math.abs(e) < 1e-5 || Math.abs(d) < 1e-6) break;
          t -= e / d;
        }
        t = Math.min(1, Math.max(0, t));
        return ((ay * t + by) * t + cy) * t;
      };
    }

    return t -> Math.min(1, Math.max(0, t));
  }

  public static double now() {
    return System.nanoTime() / 1e9;
  }

  private final Map<PlacemarkMapObjectController, Boolean> active = new IdentityHashMap<>();
  private boolean scheduled = false;

  public void add(PlacemarkMapObjectController controller) {
    active.put(controller, true);

    if (!scheduled) {
      scheduled = true;
      Choreographer.getInstance().postFrameCallback(this);
    }
  }

  public void remove(PlacemarkMapObjectController controller) {
    active.remove(controller);
  }

  public void stop() {
    active.clear();
  }

  @Override
  public void doFrame(long frameTimeNanos) {
    scheduled = false;
    double now = now();

    for (PlacemarkMapObjectController controller : new ArrayList<>(active.keySet())) {
      if (!controller.step(now, true)) {
        active.remove(controller);
      }
    }

    if (!active.isEmpty()) {
      scheduled = true;
      Choreographer.getInstance().postFrameCallback(this);
    }
  }
}
