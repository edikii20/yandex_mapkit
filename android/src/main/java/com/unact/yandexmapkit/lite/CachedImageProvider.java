package com.unact.yandexmapkit.lite;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import com.yandex.runtime.image.ImageProvider;

public class CachedImageProvider extends ImageProvider {
  private final String id;
  private final byte[] data;
  public final int width;
  public final int height;

  public CachedImageProvider(String id, byte[] data) {
    this.id = id;
    this.data = data;

    BitmapFactory.Options options = new BitmapFactory.Options();
    options.inJustDecodeBounds = true;
    BitmapFactory.decodeByteArray(data, 0, data.length, options);
    this.width = options.outWidth;
    this.height = options.outHeight;
  }

  @Override
  public String getId() {
    return id;
  }

  @Override
  public Bitmap getImage() {
    return BitmapFactory.decodeByteArray(data, 0, data.length);
  }
}
