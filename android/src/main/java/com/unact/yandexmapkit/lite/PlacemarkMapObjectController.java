package com.unact.yandexmapkit.lite;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.PointF;

import androidx.annotation.NonNull;

import com.yandex.mapkit.ScreenPoint;
import com.yandex.mapkit.geometry.Point;
import com.yandex.mapkit.map.BaseMapObjectCollection;
import com.yandex.mapkit.map.ClusterizedPlacemarkCollection;
import com.yandex.mapkit.map.CompositeIcon;
import com.yandex.mapkit.map.IconStyle;
import com.yandex.mapkit.map.MapObject;
import com.yandex.mapkit.map.MapObjectCollection;
import com.yandex.mapkit.map.MapObjectDragListener;
import com.yandex.mapkit.map.MapObjectTapListener;
import com.yandex.mapkit.map.PlacemarkMapObject;
import com.yandex.mapkit.map.RotationType;
import com.yandex.mapkit.map.TextStyle;
import com.yandex.runtime.image.ImageProvider;

import java.io.InputStream;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;
import java.util.List;
import java.util.Map;

import io.flutter.FlutterInjector;

public class PlacemarkMapObjectController
  extends MapObjectController
  implements MapObjectTapListener, MapObjectDragListener
{
  private final boolean internallyControlled;
  public final PlacemarkMapObject placemark;
  private boolean consumeTapEvents = false;
  private final WeakReference<YandexMapController> controller;
  public final String id;
  private ImageProvider baseImage;
  private Map<String, Object> baseStyle;
  private float baseOpacity = 1;
  private ImageProvider shownImage;
  private double animScale = 1;
  private double animOpacity = 1;
  private double animOffsetX = 0;
  private double animOffsetY = 0;
  private ImageProvider frameImage;
  private final List<PlacemarkAnimator.Track> tracks = new ArrayList<>();
  private String transitionId;

  @SuppressWarnings({"ConstantConditions"})
  public PlacemarkMapObjectController(
    BaseMapObjectCollection parent,
    Map<String, Object> params,
    WeakReference<YandexMapController> controller
  ) {
    PlacemarkMapObject placemark = null;

    if (parent instanceof ClusterizedPlacemarkCollection) {
      placemark = ((ClusterizedPlacemarkCollection) parent).addPlacemark();
    }

    if (parent instanceof MapObjectCollection) {
       placemark = ((MapObjectCollection) parent).addPlacemark();
    }

    this.placemark = placemark;
    this.id = (String) params.get("id");
    this.controller = controller;
    this.internallyControlled = false;

    placemark.setUserData(id);
    placemark.addTapListener(this);
    placemark.setDragListener(this);
    update(params);
  }

  public PlacemarkMapObjectController(
    PlacemarkMapObject placemark,
    Map<String, Object> params,
    WeakReference<YandexMapController> controller
  ) {
    this.placemark = placemark;
    this.id = (String) params.get("id");
    this.controller = controller;
    this.internallyControlled = true;

    placemark.setUserData(id);
    placemark.addTapListener(this);
    placemark.setDragListener(this);
    update(params);
  }
  @SuppressWarnings({"unchecked", "ConstantConditions"})
  public void update(Map<String, Object> params) {
    if (!internallyControlled) {
      placemark.setGeometry(UtilsLite.pointFromJson((Map<String, Object>) params.get("point")));
      placemark.setVisible((Boolean) params.get("isVisible"));
    }

    placemark.setZIndex(((Double) params.get("zIndex")).floatValue());
    placemark.setDraggable((Boolean) params.get("isDraggable"));
    baseOpacity = ((Double) params.get("opacity")).floatValue();
    placemark.setDirection(((Double) params.get("direction")).floatValue());

    setText(((Map<String, Object>) params.get("text")));
    setIcon(((Map<String, Object>) params.get("icon")));
    startTransition((Map<String, Object>) params.get("transition"));
    applyAnimation();

    consumeTapEvents = (Boolean) params.get("consumeTapEvents");
  }

  public void remove() {
    YandexMapController mapController = controller.get();
    if (mapController != null) {
      mapController.placemarkAnimator.remove(this);
    }

    if (internallyControlled) {
      return;
    }

    placemark.getParent().remove(placemark);
  }

  @SuppressWarnings({"unchecked", "ConstantConditions"})
  private void setIcon(Map<String, Object> icon) {
    if (icon == null) {
      return;
    }

    String iconType = ((String) icon.get("type"));

    if (iconType.equals("single")) {
      Map<String, Object> style = ((Map<String, Object>) icon.get("style"));
      Map<String, Object> image = ((Map<String, Object>) style.get("image"));

      baseImage = getIconImage(image);
      baseStyle = style;
    }

    if (iconType.equals("composite")) {
      baseImage = null;
      baseStyle = null;
      shownImage = null;
      CompositeIcon compositeIcon = placemark.useCompositeIcon();
      List<Map<String, Object>> iconParts = ((List<Map<String, Object>>) icon.get("iconParts"));

      for (Map<String, Object> iconPart: iconParts) {
        Map<String, Object> style = ((Map<String, Object>) iconPart.get("style"));
        Map<String, Object> image = ((Map<String, Object>) style.get("image"));
        String name = (String) iconPart.get("name");

        compositeIcon.setIcon(name, getIconImage(image), getIconStyle(style));
      }
    }
  }

  @SuppressWarnings({"unchecked", "ConstantConditions"})
  private void setText(Map<String, Object> text) {
    if (text == null) {
      return;
    }

    placemark.setText((String) text.get("text"), getTextStyle(((Map<String, Object>) text.get("style"))));
  }

  @SuppressWarnings({"ConstantConditions"})
  private ImageProvider getIconImage(Map<String, Object> image) {
    String type = (String) image.get("type");
    ImageProvider defaultImage = ImageProvider.fromBitmap(Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888));

    if (type.equals("fromAssetImage")) {
      String assetName = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset((String) image.get("assetName"));

      try (InputStream i = controller.get().context.getAssets().open(assetName)) {
        Bitmap result = BitmapFactory.decodeStream(i);

        return ImageProvider.fromBitmap(result);
      } catch (java.io.IOException e) {
        return defaultImage;
      }
    }

    if (type.equals("fromBytes")) {
      byte[] rawImageData = (byte[]) image.get("rawImageData");
      Bitmap bitmap = BitmapFactory.decodeByteArray(rawImageData, 0, rawImageData.length);

      if (bitmap != null) {
        return ImageProvider.fromBitmap(bitmap);
      }

      return defaultImage;
    }

    if (type.equals("fromCache")) {
      ImageProvider cached = controller.get().imageCache.get((String) image.get("key"));

      return cached != null ? cached : defaultImage;
    }

    return defaultImage;
  }

  @SuppressWarnings({"unchecked"})
  private void startTransition(Map<String, Object> transition) {
    if (transition == null) {
      return;
    }

    String id = (String) transition.get("id");
    if (id == null || id.equals(transitionId)) {
      return;
    }

    transitionId = id;
    double now = PlacemarkAnimator.now();
    List<Map<String, Object>> trackList = (List<Map<String, Object>>) transition.get("tracks");

    if (trackList != null) {
      Set<Integer> properties = new HashSet<>();
      for (Map<String, Object> json : trackList) {
        properties.add(((Number) json.get("property")).intValue());
      }

      Iterator<PlacemarkAnimator.Track> iterator = tracks.iterator();
      while (iterator.hasNext()) {
        if (properties.contains(iterator.next().property)) {
          iterator.remove();
        }
      }

      for (Map<String, Object> json : trackList) {
        int property = ((Number) json.get("property")).intValue();
        double current = property == PlacemarkAnimator.SCALE ? animScale : animOpacity;
        tracks.add(new PlacemarkAnimator.Track(json, now, current, this::getIconImage));
      }
    }

    if (!tracks.isEmpty()) {
      step(now, false);
      YandexMapController mapController = controller.get();
      if (mapController != null) {
        mapController.placemarkAnimator.add(this);
      }
    }
  }

  public boolean step(double now, boolean apply) {
    Set<Integer> seen = new HashSet<>();

    for (PlacemarkAnimator.Track track : tracks) {
      boolean isFirst = seen.add(track.property);
      if (now < track.start && !isFirst) {
        continue;
      }

      double p = track.progress(now);

      switch (track.property) {
        case PlacemarkAnimator.SCALE:
          animScale = track.from + (track.to - track.from) * p;
          break;
        case PlacemarkAnimator.OPACITY:
          animOpacity = track.from + (track.to - track.from) * p;
          break;
        case PlacemarkAnimator.OFFSET:
          applyOffset(track, p);
          break;
        default:
          if (track.isFinished(now) || track.frames.isEmpty()) {
            frameImage = null;
          } else {
            int index = (int) Math.round(Math.min(1, Math.max(0, p)) * (track.frames.size() - 1));
            frameImage = track.frames.get(index);
          }
      }
    }

    boolean running = false;
    Iterator<PlacemarkAnimator.Track> iterator = tracks.iterator();
    while (iterator.hasNext()) {
      PlacemarkAnimator.Track track = iterator.next();
      if (!track.isFinished(now)) {
        running = true;
      } else if (!(track.property == PlacemarkAnimator.OFFSET && track.toPoint != null)) {
        iterator.remove();
      }
    }

    if (apply) {
      applyAnimation();
    }

    return running;
  }

  private void applyOffset(PlacemarkAnimator.Track track, double p) {
    YandexMapController mapController = controller.get();
    ScreenPoint own = mapController != null ? mapController.screenPoint(placemark.getGeometry()) : null;
    animOffsetX = 0;
    animOffsetY = 0;

    if (own == null) {
      return;
    }

    if (track.fromPoint != null) {
      ScreenPoint target = mapController.screenPoint(track.fromPoint);
      if (target != null) {
        animOffsetX = (target.getX() - own.getX()) * (1 - p);
        animOffsetY = (target.getY() - own.getY()) * (1 - p);
      }
    } else if (track.toPoint != null) {
      ScreenPoint target = mapController.screenPoint(track.toPoint);
      if (target != null) {
        animOffsetX = (target.getX() - own.getX()) * p;
        animOffsetY = (target.getY() - own.getY()) * p;
      }
    }
  }

  @SuppressWarnings({"ConstantConditions"})
  private void applyAnimation() {
    placemark.setOpacity((float) Math.max(0, Math.min(1, baseOpacity * animOpacity)));

    ImageProvider image = frameImage != null ? frameImage : baseImage;
    if (image == null || baseStyle == null) {
      return;
    }

    IconStyle style = getIconStyle(baseStyle);
    double scale = Math.max(0.001, (style.getScale() != null ? style.getScale() : 1f) * animScale);
    style.setScale((float) scale);

    if (animOffsetX != 0 || animOffsetY != 0) {
      PointF anchor = style.getAnchor() != null ? style.getAnchor() : new PointF(0.5f, 0.5f);
      int imageWidth;
      int imageHeight;
      if (image instanceof CachedImageProvider) {
        imageWidth = ((CachedImageProvider) image).width;
        imageHeight = ((CachedImageProvider) image).height;
      } else {
        Bitmap bitmap = image.getImage();
        imageWidth = bitmap.getWidth();
        imageHeight = bitmap.getHeight();
      }
      double width = Math.max(1, imageWidth) * scale;
      double height = Math.max(1, imageHeight) * scale;
      style.setAnchor(new PointF(
        (float) (anchor.x - animOffsetX / width),
        (float) (anchor.y - animOffsetY / height)
      ));
    }

    if (image != shownImage) {
      placemark.setIcon(image, style);
      shownImage = image;
    } else {
      placemark.setIconStyle(style);
    }
  }

  @SuppressWarnings({"unchecked", "ConstantConditions"})
  private IconStyle getIconStyle(Map<String, Object> style) {
    IconStyle iconStyle = new IconStyle();

    if (style.get("tappableArea") != null) {
      iconStyle.setTappableArea(UtilsLite.rectFromJson((Map<String, Object>) style.get("tappableArea")));
    }

    iconStyle.setAnchor(UtilsLite.rectPointFromJson((Map<String, Double>) style.get("anchor")));
    iconStyle.setZIndex(((Double) style.get("zIndex")).floatValue());
    iconStyle.setScale(((Double) style.get("scale")).floatValue());
    iconStyle.setVisible((Boolean) style.get("isVisible"));
    iconStyle.setFlat((Boolean) style.get("isFlat"));
    iconStyle.setRotationType(RotationType.values()[(Integer) style.get("rotationType")]);

    return iconStyle;
  }

  @SuppressWarnings({"ConstantConditions"})
  private TextStyle getTextStyle(Map<String, Object> style) {
    TextStyle textStyle = new TextStyle();

    if (style.get("color") != null) {
      textStyle.setColor(((Number) style.get("color")).intValue());
    }

    if (style.get("outlineColor") != null) {
      textStyle.setOutlineColor(((Number) style.get("outlineColor")).intValue());
    }

    textStyle.setSize(((Double) style.get("size")).floatValue());
    textStyle.setOffset(((Double) style.get("offset")).floatValue());
    textStyle.setOffsetFromIcon((Boolean) style.get("offsetFromIcon"));
    textStyle.setTextOptional((Boolean) style.get("textOptional"));
    textStyle.setPlacement(TextStyle.Placement.values()[(Integer) style.get("placement")]);

    return textStyle;
  }

  @Override
  public void onMapObjectDragStart(@NonNull MapObject mapObject) {
    controller.get().mapObjectDragStart(id);
  }

  @Override
  public void onMapObjectDrag(@NonNull MapObject mapObject, @NonNull Point point) {
    controller.get().mapObjectDrag(id, point);
  }

  @Override
  public void onMapObjectDragEnd(@NonNull MapObject mapObject) {
    controller.get().mapObjectDragEnd(id);
  }

  @Override
  public boolean onMapObjectTap(@NonNull MapObject mapObject, @NonNull Point point) {
    controller.get().mapObjectTap(id, point);

    return consumeTapEvents;
  }
}
