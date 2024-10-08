package com.zywellthermalprinter;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.IBinder;
import android.text.TextUtils;
import android.util.Log;
import androidx.annotation.NonNull;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.module.annotations.ReactModule;
import java.util.ArrayList;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;
import net.posprinter.posprinterface.PrinterBinder;
import net.posprinter.posprinterface.ProcessData;
import net.posprinter.posprinterface.TaskCallback;
import net.posprinter.service.PrinterConnectionsService;
import net.posprinter.utils.BitmapProcess;
import net.posprinter.utils.BitmapToByteData;
import net.posprinter.utils.DataForSendToPrinterPos58;
import net.posprinter.utils.DataForSendToPrinterPos80;
import net.posprinter.utils.DataForSendToPrinterTSC;
import net.posprinter.utils.RoundQueue;
import net.posprinter.utils.StringUtils;

@ReactModule(name = ZywellThermalPrinterModule.NAME)
public class ZywellThermalPrinterModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;
  public static final String NAME = "ZywellThermalPrinter";
  public static PrinterBinder printerBinder;

  ServiceConnection printerSerconnection = new ServiceConnection() {
    @Override
    public void onServiceConnected(ComponentName name, IBinder service) {
      printerBinder = (PrinterBinder)service;
      Log.e("printerBinder", "connect");
    }

    @Override
    public void onServiceDisconnected(ComponentName name) {
      printerBinder = null;
      Log.e("printerBinder", "disconnect");
    }
  };

  public ZywellThermalPrinterModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;

    Intent intentPrinter =
        new Intent(reactContext, PrinterConnectionsService.class);
    reactContext.bindService(intentPrinter, printerSerconnection,
                             Context.BIND_AUTO_CREATE);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  public Bitmap convertGreyImg(Bitmap img) {
    int width = img.getWidth();
    int height = img.getHeight();

    int[] pixels = new int[width * height];

    img.getPixels(pixels, 0, width, 0, 0, width, height);

    // The arithmetic average of a grayscale image; a threshold
    double redSum = 0, greenSum = 0, blueSun = 0;
    double total = width * height;

    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        int grey = pixels[width * i + j];

        int red = ((grey & 0x00FF0000) >> 16);
        int green = ((grey & 0x0000FF00) >> 8);
        int blue = (grey & 0x000000FF);

        redSum += red;
        greenSum += green;
        blueSun += blue;
      }
    }
    int m = (int)(redSum / total);

    // Conversion monochrome diagram
    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        int grey = pixels[width * i + j];

        int alpha1 = 0xFF << 24;
        int red = ((grey & 0x00FF0000) >> 16);
        int green = ((grey & 0x0000FF00) >> 8);
        int blue = (grey & 0x000000FF);

        if (red >= m) {
          red = green = blue = 255;
        } else {
          red = green = blue = 0;
        }
        grey = alpha1 | (red << 16) | (green << 8) | blue;
        pixels[width * i + j] = grey;
      }
    }
    Bitmap mBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565);
    mBitmap.setPixels(pixels, 0, width, 0, 0, width, height);
    return mBitmap;
  }

  @ReactMethod
  public void connectNet(String ip_address, final Promise promise) {
    if (ip_address != "") {
      boolean isConnected = printerBinder.isConnect(ip_address);
      Log.d("isConnected", "readBuffer ip: " + ip_address +
                               " isConnected: " + isConnected + "");
      if (isConnected) {
        printerBinder.disconnectCurrentPort(ip_address, new TaskCallback() {
          @Override
          public void OnSucceed() {
            printerBinder.connectNetPort(ip_address, new TaskCallback() {
              @Override
              public void OnSucceed() {
                Log.d("ip_address", "readBuffer ip: " + ip_address);
                promise.resolve(ip_address);
              }

              @Override
              public void OnFailed() {
                promise.reject(new Exception("CONNECT_NET_FAIL"));
              }
            });
          }

          @Override
          public void OnFailed() {
            promise.reject("DisconnectFailed",
                           "Failed to disconnect the printer");
          }
        });
      } else {
        printerBinder.connectNetPort(ip_address, new TaskCallback() {
          @Override
          public void OnSucceed() {
            promise.resolve(ip_address);
          }

          @Override
          public void OnFailed() {
            promise.reject(new Exception("CONNECT_NET_FAIL"));
          }
        });
      }
    } else {
      promise.reject(new Exception("CONNECT_NET_FAIL_IP_NULL"));
    }
  }

  @ReactMethod
  public void connectBLE(String address, final Promise promise) {
    if (address != "") {
      printerBinder.connectBtPort(address, new TaskCallback() {
        @Override
        public void OnSucceed() {
          promise.resolve(address);
        }

        @Override
        public void OnFailed() {
          promise.reject(new Exception("CONNECT_BLE_FAIL"));
        }
      });
    } else {
      promise.reject(new Exception("CONNECT_BLE_FAIL_IP_NULL"));
    }
  }

  @ReactMethod
  public void printPic(String address, String imagePath,
                       final ReadableMap options, final Promise promise) {
    Uri imageUri = Uri.parse(imagePath);
    String realPath = imageUri.getPath();

    int size = options.getInt("size");
    int width = options.getInt("width");

    final boolean isDisconnect;
    if (options.hasKey("is_disconnect")) {
      isDisconnect = options.getBoolean("is_disconnect");
    } else {
      isDisconnect = false;
    }

    final boolean isCutPaper;
    if (options.hasKey("cut_paper")) {
      isCutPaper = options.getBoolean("cut_paper");
    } else {
      isCutPaper = true;
    }

    String mode;
    if (options.hasKey("mode")) {
      mode = options.getString("mode");
    } else {
      mode = "THERMAL";
    }

    final Bitmap bitmap = BitmapFactory.decodeFile(realPath);
    if (mode.equals("LABEL")) {
      int paper_size;
      if (options.hasKey("paper_size")) {
        paper_size = options.getInt("paper_size");
      } else {
        paper_size = 50;
      }
      if (bitmap != null && address != null) {
        final Bitmap bitmap1 =
            BitmapProcess.compressBmpByYourWidth(bitmap, width);
        final Bitmap bitmapToPrint = convertGreyImg(bitmap1);
        printerBinder.writeDataByYouself(
            address,
            new TaskCallback() {
              @Override
              public void OnSucceed() {
                promise.resolve("SEND_SUCCESS");
                if (isDisconnect) {
                  TimerTask task = new TimerTask() {
                    @Override
                    public void run() {
                      printerBinder.disconnectCurrentPort(
                          address, new TaskCallback() {
                            @Override
                            public void OnSucceed() {
                              Log.d("disconnectCurrentPort",
                                    "disconnect success");
                            }

                            @Override
                            public void OnFailed() {}
                          });
                    }
                  };
                  Timer timer = new Timer();
                  timer.schedule(task, 1500);
                }
              }

              @Override
              public void OnFailed() {
                promise.reject(new Exception("SEND_ERROR"));
              }
            },
            new ProcessData() {
              @Override
              public List<byte[]> processDataBeforeSend() {
                List<byte[]> list = new ArrayList<>();
                // 设置标签纸大小
                list.add(DataForSendToPrinterTSC.sizeBymm(paper_size, 30));
                // 设置间隙
                list.add(DataForSendToPrinterTSC.gapBymm(3, 0));
                // 清除缓存
                list.add(DataForSendToPrinterTSC.cls());
                list.add(DataForSendToPrinterTSC.bitmap(
                    -2, 10, 0, bitmapToPrint,
                    BitmapToByteData.BmpType.Threshold));
                list.add(DataForSendToPrinterTSC.print(1));
                return list;
              }
            });
      } else {
        promise.reject(new Exception("NOT_CONNECT_TO_PRINTER"));
      }
    } else {
      if (bitmap != null && address != null) {
        final Bitmap bitmap1 =
            BitmapProcess.compressBmpByYourWidth(bitmap, width);
        final Bitmap bitmapToPrint = convertGreyImg(bitmap1);
        printerBinder.writeDataByYouself(
            address,
            new TaskCallback() {
              @Override
              public void OnSucceed() {
                promise.resolve("SEND_SUCCESS");
                if (isDisconnect) {
                  TimerTask task = new TimerTask() {
                    @Override
                    public void run() {
                      printerBinder.disconnectCurrentPort(
                          address, new TaskCallback() {
                            @Override
                            public void OnSucceed() {
                              Log.d("disconnectCurrentPort",
                                    "disconnect success");
                            }

                            @Override
                            public void OnFailed() {}
                          });
                    }
                  };
                  Timer timer = new Timer();
                  timer.schedule(task, 3000);
                }
              }

              @Override
              public void OnFailed() {
                promise.reject(new Exception("SEND_ERROR"));
              }
            },
            new ProcessData() {
              @Override
              public List<byte[]> processDataBeforeSend() {
                List<byte[]> list = new ArrayList<>();
                if (size == 58) {
                  list.add(DataForSendToPrinterPos58.initializePrinter());
                } else {
                  list.add(DataForSendToPrinterPos80.initializePrinter());
                }
                List<Bitmap> blist = new ArrayList<>();
                blist = BitmapProcess.cutBitmap(50, bitmapToPrint);
                for (int i = 0; i < blist.size(); i++) {
                  if (size == 58) {
                    list.add(DataForSendToPrinterPos58.printRasterBmp(
                        0, blist.get(i), BitmapToByteData.BmpType.Dithering,
                        BitmapToByteData.AlignType.Left, width));
                  } else {
                    list.add(DataForSendToPrinterPos80.printRasterBmp(
                        0, blist.get(i), BitmapToByteData.BmpType.Dithering,
                        BitmapToByteData.AlignType.Left, width));
                  }
                }

                if (size == 58 && isCutPaper) {
                  list.add(DataForSendToPrinterPos58.printAndFeedLine());
                } else if (isCutPaper) {
                  list.add(DataForSendToPrinterPos80.printAndFeedLine());
                }

                if (size == 80 && isCutPaper) {
                  list.add(
                      DataForSendToPrinterPos80.selectCutPagerModerAndCutPager(
                          0x42, 0x66));
                }
                return list;
              }
            });
      } else {
        promise.reject(new Exception("NOT_CONNECT_TO_PRINTER"));
      }
    }
  }

  @ReactMethod
  public void printText(String address, String text, final Promise promise) {
    if (!TextUtils.isEmpty(text)) {
      printerBinder.writeDataByYouself(
          address,
          new TaskCallback() {
            @Override
            public void OnSucceed() {
              promise.resolve("PRINT_SUCCESS");
            }

            @Override
            public void OnFailed() {
              promise.reject(new Exception("PRINT_FAIL"));
            }
          },
          new ProcessData() {
            @Override
            public List<byte[]> processDataBeforeSend() {
              List<byte[]> list = new ArrayList<>();
              list.add(DataForSendToPrinterPos58.initializePrinter());
              list.add(StringUtils.strTobytes(text));
              list.add(DataForSendToPrinterPos58.printAndFeedLine());
              return list;
            }
          });
    } else {
      promise.reject(new Exception("PRINT_FAIL_NOT_CONNECT"));
    }
  }

  @ReactMethod
  public void isConnect(String ip, Promise promise) {
    if (ip != null) {
      boolean isConnected = printerBinder.isConnect(ip);
      promise.resolve(isConnected);
    } else {
      promise.reject("InvalidArgument", "IP address is null");
    }
  }

  @ReactMethod
  public void readBuffer(String ip, Promise promise) {
    if (ip != null) {
      RoundQueue<byte[]> queue = printerBinder.readBuffer(ip);
      if (queue != null && queue.realSize() > 0) {
        // The queue is not empty
        WritableMap result = Arguments.createMap();
        result.putInt("queueSize", queue.realSize());
        promise.resolve(result);
      } else {
        // The queue is empty
        promise.resolve(null);
      }
    } else {
      promise.reject("InvalidArgument", "IP address is null");
    }
  }

  @ReactMethod
  public void clearBuffer(String ip, Promise promise) {
    if (ip != null) {
      printerBinder.clearBuffer(ip);
      promise.resolve(true);
    } else {
      promise.reject("InvalidArgument", "IP address is null");
    }
  }

  @ReactMethod
  public void disconnectPort(String ip, Promise promise) {
    if (ip != null) {
      printerBinder.disconnectCurrentPort(ip, new TaskCallback() {
        @Override
        public void OnSucceed() {
          promise.resolve(true);
        }

        @Override
        public void OnFailed() {
          promise.reject("DisconnectFailed",
                         "Failed to disconnect the printer");
        }
      });
    } else {
      promise.reject("InvalidArgument", "IP address is null");
    }
  }

  @ReactMethod
  public void disconnectAll(final Promise promise) {
    printerBinder.disconnectAll(new TaskCallback() {
      @Override
      public void OnSucceed() {
        promise.resolve("DISCONNECT_ALL_SUCCESS");
      }

      @Override
      public void OnFailed() {
        promise.reject(new Exception("DISCONNECT_ALL_FAIL"));
      }
    });
  }
}
