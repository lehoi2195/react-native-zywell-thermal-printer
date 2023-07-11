package com.zywellthermalprinter;

import androidx.annotation.NonNull;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;

import net.posprinter.posprinterface.PrinterBinder;
import net.posprinter.posprinterface.ProcessData;
import net.posprinter.posprinterface.TaskCallback;
import net.posprinter.service.PrinterConnectionsService;
import net.posprinter.utils.BitmapProcess;
import net.posprinter.utils.BitmapToByteData;
import net.posprinter.utils.DataForSendToPrinterPos58;
import net.posprinter.utils.StringUtils;

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
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

@ReactModule(name = ZywellThermalPrinterModule.NAME)
public class ZywellThermalPrinterModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;
  public static final String NAME = "ZywellThermalPrinterModule";
  public static PrinterBinder printerBinder;


  ServiceConnection printerSerconnection = new ServiceConnection() {
    @Override
    public void onServiceConnected(ComponentName name, IBinder service) {
      printerBinder = (PrinterBinder) service;
      Log.e("printerBinder", "connect");
    }

    @Override
    public void onServiceDisconnected(ComponentName name) {
      Log.e("printerBinder", "disconnect");
    }
  };

  public ZywellThermalPrinterModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;

    Intent intentPrinter = new Intent(reactContext, PrinterConnectionsService.class);
    reactContext.bindService(intentPrinter, printerSerconnection, Context.BIND_AUTO_CREATE);
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

    //The arithmetic average of a grayscale image; a threshold
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
    int m = (int) (redSum / total);

    //Conversion monochrome diagram
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

  // Example method
  // See https://reactnative.dev/docs/native-modules-android
  @ReactMethod
  public void multiply(double a, double b, Promise promise) {
    promise.resolve(a * b);
  }

  @ReactMethod
  public void connectNet(String ip_address, final Promise promise) {
    if (ip_address != "") {
      printerBinder.connectNetPort(ip_address, new TaskCallback() {
        @Override
        public void OnSucceed() {
          Toast.makeText(reactContext, "Connect Success " + ip_address, Toast.LENGTH_SHORT).show();
          promise.resolve(ip_address);
        }

        @Override
        public void OnFailed() {
          Toast.makeText(reactContext, "Connect fail " + ip_address, Toast.LENGTH_SHORT).show();
          promise.reject(new Exception("Connect_Failed"));
        }
      });
    } else {
      Toast.makeText(reactContext, "ip_address null", Toast.LENGTH_SHORT).show();
      promise.reject(new Exception("IP_NULL"));
    }
  }

  @ReactMethod
  public void connectBT(String address, final Promise promise) {
    if (address != "") {
      printerBinder.connectBtPort(address, new TaskCallback() {
        @Override
        public void OnSucceed() {
          Toast.makeText(reactContext, "Connect BLE Success", Toast.LENGTH_SHORT).show();
          promise.resolve(address);
        }

        @Override
        public void OnFailed() {
          Toast.makeText(reactContext, "Connect BLE Fail", Toast.LENGTH_SHORT).show();
          promise.reject(new Exception("Connect_BLE_Failed"));
        }
      });
    } else {
      Toast.makeText(reactContext, "Connect BLE fail address null", Toast.LENGTH_SHORT).show();
      promise.reject(new Exception("ADDRESS_NULL"));
    }

  }

  @ReactMethod
  public void printPic(String address, String imagePath, final Promise promise) {
    Uri imageUri = Uri.parse(imagePath);
    String realPath = imageUri.getPath();

    Bitmap bitmap = BitmapFactory.decodeFile(realPath);
    if (bitmap != null && address != null) {
      final Bitmap bitmap1 = BitmapProcess.compressBmpByYourWidth(bitmap, 384);
      final Bitmap bitmapToPrint = convertGreyImg(bitmap1);
      Toast.makeText(reactContext, "Start Print " + address, Toast.LENGTH_SHORT).show();
      printerBinder.writeDataByYouself(address, new TaskCallback() {
        @Override
        public void OnSucceed() {
          Toast.makeText(reactContext, "Send Success", Toast.LENGTH_SHORT).show();
          promise.resolve("Send_Success");
        }

        @Override
        public void OnFailed() {
          Toast.makeText(reactContext, "Send Error", Toast.LENGTH_SHORT).show();
          promise.reject(new Exception("Send_Error"));
        }
      }, new ProcessData() {
        @Override
        public List<byte[]> processDataBeforeSend() {
          List<byte[]> list = new ArrayList<>();
          list.add(DataForSendToPrinterPos58.initializePrinter());
          List<Bitmap> blist = new ArrayList<>();
          blist = BitmapProcess.cutBitmap(50, bitmapToPrint);
          for (int i = 0; i < blist.size(); i++) {
            list.add(DataForSendToPrinterPos58.printRasterBmp(0, blist.get(i), BitmapToByteData.BmpType.Dithering, BitmapToByteData.AlignType.Left, 384));
          }
          list.add(DataForSendToPrinterPos58.printAndFeedLine());
          return list;
        }
      });
    } else {
      promise.reject(new Exception("Print_Error: NOT_CONNECT_TO_PRINTER"));
      Toast.makeText(reactContext, "Need connect first", Toast.LENGTH_SHORT).show();
    }
  }

  @ReactMethod
  public void printText(String address, String text, final Promise promise) {
    if (!TextUtils.isEmpty(text)) {
      printerBinder.writeDataByYouself(address, new TaskCallback() {
        @Override
        public void OnSucceed() {
          Toast.makeText(reactContext, "Print Success", Toast.LENGTH_SHORT).show();
          promise.resolve("Print_Success");
        }

        @Override
        public void OnFailed() {
          Toast.makeText(reactContext, "Print Fail", Toast.LENGTH_SHORT).show();
          promise.reject(new Exception("Print Error"));
        }
      }, new ProcessData() {
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
      Toast.makeText(reactContext, "Not Connect", Toast.LENGTH_SHORT).show();
      promise.reject(new Exception("Print Error: Not Connect"));
    }
  }

  @ReactMethod
  public boolean isConnect(String ip) {
    if (ip != null) {
      boolean status = printerBinder.isConnect(ip);
      Log.e("PrinterConnect", "isConnect ip: " + ip + " --- " + status);
      return status;
    } else {
      return false;
    }
  }

  @ReactMethod
  public void clearBuffer(String ip) {
    printerBinder.clearBuffer(ip);
  }

  @ReactMethod
  public void disconnectPort(String address, final Promise promise) {
    if (address != "") {
      printerBinder.disconnectCurrentPort(address, new TaskCallback() {
        @Override
        public void OnSucceed() {
          Toast.makeText(reactContext, "Disconnect Port Success", Toast.LENGTH_SHORT).show();
          promise.resolve("Disconnect_Port_Success");
        }

        @Override
        public void OnFailed() {
          Toast.makeText(reactContext, "Disconnect Port Fail", Toast.LENGTH_SHORT).show();
          promise.reject(new Exception("Disconnect Port_Error"));
        }
      });
    }

  }

  @ReactMethod
  public void disconnectAll(final Promise promise) {
    printerBinder.disconnectAll(new TaskCallback() {
      @Override
      public void OnFailed() {
        Toast.makeText(reactContext, "DisconnectAll Fail", Toast.LENGTH_SHORT).show();
        promise.reject(new Exception("DisconnectAll_Error"));
      }

      @Override
      public void OnSucceed() {
        Toast.makeText(reactContext, "DisconnectAll Success", Toast.LENGTH_SHORT).show();
        promise.resolve("DisconnectAll_Success");
      }
    });
  }
}
