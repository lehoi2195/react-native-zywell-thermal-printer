// ZywellThermalPrinter.m

#import "ZywellThermalPrinter.h"
#import "BLEManager.h"
#import "ImageTranster.h"
#import "POSSDK.h"
#import "PosCommand.h"
#import "TscCommand.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreGraphics/CoreGraphics.h>

@interface ZywellThermalPrinter () <BLEManagerDelegate, POSWIFIManagerDelegate>

@property(nonatomic, strong) POSWIFIManager *wifiManager;
@property(strong, nonatomic) BLEManager *bleManager;
@property(nonatomic, strong)
    NSMutableArray<CBPeripheral *> *connectedPeripherals;

@end

@implementation ZywellThermalPrinter
NSMutableDictionary<NSString *, POSWIFIManager *> *wifiManagerDictionary;

RCT_EXPORT_MODULE();

- (POSWIFIManager *)wifiManager {
  if (!_wifiManager) {
    _wifiManager = [POSWIFIManager shareWifiManager];
    _wifiManager.delegate = self;
  }
  return _wifiManager;
}

- (BLEManager *)bleManager {
  if (!_bleManager) {
    _bleManager = [[BLEManager alloc] init];
  }
  return _bleManager;
}

- (instancetype)init {
  if (self = [super init]) {
    wifiManagerDictionary = [NSMutableDictionary dictionary];
    _bleManager.delegate = self;
    _connectedPeripherals = [NSMutableArray array];
  }
  return self;
}

- (dispatch_queue_t)methodQueue {
  return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(connectNet
                  : (NSString *)ip_address resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject) {
  POSWIFIManager *wifiManager = wifiManagerDictionary[ip_address];
  if (!wifiManager) {
    wifiManager = [[POSWIFIManager alloc] init];
    wifiManager.delegate = self;
    wifiManagerDictionary[ip_address] = wifiManager;
  }

  [wifiManager POSDisConnect];
  [wifiManager
      POSConnectWithHost:ip_address
                    port:9100
              completion:^(BOOL isConnect) {
                if (isConnect) {
                  resolve(@(YES));
                  NSLog(@"Connect Success");
                } else {
                  NSError *error = [NSError
                      errorWithDomain:@"ZywellPrinterErrorDomain"
                                 code:1001
                             userInfo:@{
                               NSLocalizedDescriptionKey : @"Connection failed"
                             }];
                  reject(@"connect_failed", @"Failed to connect to the printer",
                         error);
                }
              }];
}

- (UIImage *)convertToGrayScaleWithBlackAndWhite:(UIImage *)sourceImage {
  if (!sourceImage) {
    NSLog(@"Source image is nil");
    return nil;
  }

  CGSize size = sourceImage.size;
  CGRect rect = CGRectMake(0.0, 0.0, size.width, size.height);

  // Create a new image context with grayscale color space
  UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
  CGContextRef context = UIGraphicsGetCurrentContext();

  // Draw the image in grayscale
  [sourceImage drawInRect:rect blendMode:kCGBlendModeLuminosity alpha:1.0];

  // Get the grayscale image from the context
  UIImage *grayImage = UIGraphicsGetImageFromCurrentImageContext();

  // End the context
  UIGraphicsEndImageContext();

  // Convert the grayscale image to black and white
  CGRect imageRect =
      CGRectMake(0.0, 0.0, grayImage.size.width, grayImage.size.height);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  CGContextRef bitmapContext = CGBitmapContextCreate(
      NULL, grayImage.size.width, grayImage.size.height, 8,
      grayImage.size.width, colorSpace, kCGImageAlphaNone);
  CGColorSpaceRelease(colorSpace);

  CGContextDrawImage(bitmapContext, imageRect, [grayImage CGImage]);
  CGImageRef bwImageRef = CGBitmapContextCreateImage(bitmapContext);
  CGContextRelease(bitmapContext);

  UIImage *bwImage = [UIImage imageWithCGImage:bwImageRef];
  CGImageRelease(bwImageRef);

  return bwImage;
}

- (UIImage *)imageCompressForWidthScaleWithImagePath:(NSString *)imagePath
                                         targetWidth:(CGFloat)defineWidth {

  // Load UIImage from imagePath

  UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
  UIImage *sourceImage = [self convertToGrayScaleWithBlackAndWhite:image];
  if (!sourceImage) {
    NSLog(@"Failed to load image from path: %@", imagePath);
    return nil;
  }

  UIImage *newImage = nil;
  CGSize imageSize = sourceImage.size;
  CGFloat width = imageSize.width;
  CGFloat height = imageSize.height;
  CGFloat targetWidth = defineWidth;
  CGFloat targetHeight = height / (width / targetWidth);
  CGSize size = CGSizeMake(targetWidth, targetHeight);
  CGFloat scaleFactor = 0.0;
  CGFloat scaledWidth = targetWidth;
  CGFloat scaledHeight = targetHeight;
  CGPoint thumbnailPoint = CGPointMake(0.0, 0.0);

  if (CGSizeEqualToSize(imageSize, size) == NO) {

    CGFloat widthFactor = targetWidth / width;
    CGFloat heightFactor = targetHeight / height;

    if (widthFactor > heightFactor) {
      scaleFactor = widthFactor;
    } else {
      scaleFactor = heightFactor;
    }
    scaledWidth = width * scaleFactor;
    scaledHeight = height * scaleFactor;

    if (widthFactor > heightFactor) {
      thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
    } else if (widthFactor < heightFactor) {
      thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
    }
  }

  UIGraphicsBeginImageContext(size);

  CGRect thumbnailRect = CGRectZero;
  thumbnailRect.origin = thumbnailPoint;
  thumbnailRect.size.width = scaledWidth;
  thumbnailRect.size.height = scaledHeight;

  [sourceImage drawInRect:thumbnailRect];

  newImage = UIGraphicsGetImageFromCurrentImageContext();

  if (newImage == nil) {
    NSLog(@"Failed to scale image");
  }

  UIGraphicsEndImageContext();

  return newImage;
}

RCT_EXPORT_METHOD(printPic
                  : (NSString *)ipAddress imagePath
                  : (NSString *)imagePath printerOptions
                  : (NSDictionary *)options resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject) {
  @try {

    POSWIFIManager *wifiManager = wifiManagerDictionary[ipAddress];
    if (!wifiManager) {
      NSError *error = [NSError
          errorWithDomain:@"ZywellModuleErrorDomain"
                     code:1002
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Printer is not connected"
                 }];
      reject(@"printer_not_connected", @"Printer is not connected", error);
      return;
    }

    NSString *mode = options[@"mode"];
    NSString *labelString = @"LABEL";

    if ([mode isEqualToString:labelString]) {
      // mode là chuỗi "LABEL"
      NSLog(@"mode is equal to LABEL");
      BOOL isDisconnect = [options[@"is_disconnect"]
          boolValue]; // Get the boolean value from options dictionary
      BOOL isResolve = [options[@"is_resolve"]
          boolValue]; // Get the boolean value from options dictionary
      int nWidth = [options[@"width"] intValue];
      NSNumber *paperSizeNumber = options[@"paper_size"];
      int paper_size = [options[@"paper_size"] intValue];
      if (paperSizeNumber == nil || ![paperSizeNumber isKindOfClass:[NSNumber class]]) {
        // If the "paper_size" key is missing or the value is not a valid number, set default to 50
        paper_size = 50;
      } else {
        // Convert the paperSizeNumber to an integer using the intValue method
        paper_size = [paperSizeNumber intValue];
      }
      NSInteger width = ((int)((nWidth + 7) / 8)) * 8;
      UIImage *newImage =
          [self imageCompressForWidthScaleWithImagePath:imagePath
                                            targetWidth:width];

      NSMutableData *dataM = [[NSMutableData alloc] init];
      NSData *data = [[NSData alloc] init];
      //    data=[self.codeTextField.text
      //    dataUsingEncoding:NSASCIIStringEncoding];
      data = [TscCommand sizeBymmWithWidth:paper_size andHeight:30];
      [dataM appendData:data];
      data = [TscCommand gapBymmWithWidth:3 andHeight:0];
      [dataM appendData:data];
      data = [TscCommand cls];
      [dataM appendData:data];
      data = [TscCommand bitmapWithX:-2
                                andY:10
                             andMode:0
                            andImage:newImage
                          andBmpType:Dithering];
      [dataM appendData:data];
      data = [TscCommand print:1];
      [dataM appendData:data];
      [wifiManager POSWriteDataWithCallback:dataM
          completion:^(BOOL success) {
          if (success && isDisconnect) {
            dispatch_time_t popTime =
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(3.0 * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(),
                            ^{
                              [wifiManager POSDisConnect];
                            });
          }
          if (success && isResolve) {
            resolve(@(YES));
          }
        }];
    } else {
      // mode không giống "LABEL"
      NSLog(@"mode is NOT equal to LABEL");
      int nWidth = [options[@"width"] intValue];

      NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
      CIImage *inputImage = [CIImage imageWithContentsOfURL:imageURL];

      // Create a black and white filter
      CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
      [filter setValue:inputImage forKey:kCIInputImageKey];
      [filter setValue:@(0.0)
                forKey:kCIInputSaturationKey]; // Set saturation to 0 to remove
                                               // color
      BOOL isDisconnect = [options[@"is_disconnect"]
          boolValue]; // Get the boolean value from options dictionary
      BOOL isResolve = [options[@"is_resolve"]
          boolValue]; // Get the boolean value from options dictionary

      // Apply the filter and get the output image
      CIImage *outputImage = [filter outputImage];

      // Create a CIContext to render the output image
      CIContext *context = [CIContext context];
      CGImageRef outputCGImage = [context createCGImage:outputImage
                                               fromRect:[outputImage extent]];

      // Convert the output CGImage to a UIImage
      UIImage *newImage = [UIImage imageWithCGImage:outputCGImage];

      NSInteger imgHeight = newImage.size.height;
      NSInteger imagWidth = newImage.size.width;
      NSInteger width = ((int)((nWidth + 7) / 8)) * 8;
      CGSize size = CGSizeMake(width, imgHeight * width / imagWidth);
      UIImage *scaled = [ImageTranster imgWithImage:newImage
                                   scaledToFillSize:size];

      unsigned char *graImage = [ImageTranster imgToGreyImage:scaled];
      unsigned char *formatedData =
          [ImageTranster img_format_K_threshold:graImage
                                          width:size.width
                                         height:size.height];
      NSData *dataToPrint = [ImageTranster convertEachLinePixToCmd:formatedData
                                                            nWidth:size.width
                                                           nHeight:size.height
                                                             nMode:0];

      [wifiManager POSWriteCommandWithData:dataToPrint];
      [wifiManager POSWriteCommandWithData:[PosCommand printAndFeedLine]];
      [wifiManager POSWriteCommandWithData:[PosCommand printAndFeedLine]];
      [wifiManager POSWriteCommandWithData:[PosCommand printAndFeedLine]];
      [wifiManager POSWriteCommandWithData:[PosCommand printAndFeedLine]];
      [wifiManager
          POSWriteDataWithCallback:[PosCommand selectCutPageModelAndCutpage:0]
                        completion:^(BOOL success) {
                          if (success && isDisconnect) {
                            dispatch_time_t popTime =
                                dispatch_time(DISPATCH_TIME_NOW,
                                              (int64_t)(3.0 * NSEC_PER_SEC));
                            dispatch_after(popTime, dispatch_get_main_queue(),
                                           ^{
                                             [wifiManager POSDisConnect];
                                           });
                          }
                          if (success && isResolve) {
                            resolve(@(YES));
                          }
                        }];
    }
  } @catch (NSException *e) {
    NSError *error = [NSError
        errorWithDomain:@"RCTZywellThermalPrinterErrorDomain"
                   code:1002
               userInfo:@{NSLocalizedDescriptionKey : @"Failed to print net"}];
    reject(@"failed_to_print_net", @"Failed to print net", error);
    NSLog(@"ERROR IN PRINTING IMG: %@", [e callStackSymbols]);
  }
}

RCT_EXPORT_METHOD(disconnectNet : (NSString *)ipAddress) {
  POSWIFIManager *wifiManager = wifiManagerDictionary[ipAddress];
  if (wifiManager) {
    [wifiManager POSDisConnect];
    [wifiManagerDictionary removeObjectForKey:ipAddress];
  }
}

RCT_EXPORT_METHOD(connectBLE
                  : (NSString *)address resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
  [self.bleManager stopScan];
  CBPeripheral *peripheral = nil;
  __block BOOL foundPeripheral = NO;
  for (CBPeripheral *discoveredPeripheral in self.bleManager.peripherals) {
    if ([discoveredPeripheral.identifier.UUIDString isEqualToString:address]) {
      peripheral = discoveredPeripheral;
      foundPeripheral = YES;
      break;
    }
  }

  if (peripheral) {
    [self.bleManager
        connectPeripheral:peripheral
               completion:^(BOOL isConnected) {
                 NSLog(@"=========connectPeripheral peripheral %@", peripheral);
                 if (isConnected) {
                   self.bleManager.writePeripheral = peripheral;
                   [self.connectedPeripherals addObject:peripheral];
                   resolve(address);
                 } else {
                   NSError *error = [NSError
                       errorWithDomain:@"RCTZywellThermalPrinterErrorDomain"
                                  code:1002
                              userInfo:@{
                                NSLocalizedDescriptionKey :
                                    @"Failed to connect to the peripheral"
                              }];
                   reject(@"failed_to_connect",
                          @"Failed to connect to the peripheral", error);
                 }
               }];
  } else {
    __block BOOL stopScanning = NO;
    [self.bleManager
        startScanWithInterval:3
                   completion:^(NSArray *peripherals) {
                     if (stopScanning) {
                       return;
                     }

                     CBPeripheral *scannedPeripheral = nil;
                     for (CBPeripheral *discoveredPeripheral in peripherals) {
                       if ([discoveredPeripheral.identifier.UUIDString
                               isEqualToString:address]) {
                         scannedPeripheral = discoveredPeripheral;
                         foundPeripheral = YES;
                         break;
                       }
                     }

                     if (scannedPeripheral) {

                       [self.bleManager.peripherals
                           addObject:scannedPeripheral];
                       [self.bleManager
                           connectPeripheral:scannedPeripheral
                                  completion:^(BOOL isConnected) {
                                    if (isConnected) {
                                      NSLog(@"=========connectPeripheral "
                                            @"scannedPeripheral %@",
                                            scannedPeripheral);
                                      stopScanning = YES;
                                      [self.bleManager stopScan];
                                      self.bleManager.writePeripheral =
                                          scannedPeripheral;
                                      [self.connectedPeripherals
                                          addObject:scannedPeripheral];
                                      resolve(address);
                                    }
                                  }];
                     }
                   }];
  }
}

RCT_EXPORT_METHOD(printPicBLE
                  : (NSString *)ipAddress imagePath
                  : (NSString *)imagePath printerOptions
                  : (NSDictionary *)options resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
  @try {
    int nWidth = [options[@"width"] intValue];
    NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
    CIImage *inputImage = [CIImage imageWithContentsOfURL:imageURL];

    // Create a black and white filter
    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter
        setValue:@(0.0)
          forKey:kCIInputSaturationKey]; // Set saturation to 0 to remove color

    // Apply the filter and get the output image
    CIImage *outputImage = [filter outputImage];

    // Create a CIContext to render the output image
    CIContext *context = [CIContext context];
    CGImageRef outputCGImage = [context createCGImage:outputImage
                                             fromRect:[outputImage extent]];

    // Convert the output CGImage to a UIImage
    UIImage *newImage = [UIImage imageWithCGImage:outputCGImage];

    // Create a new UIImage object
    NSInteger imgHeight = newImage.size.height;
    NSInteger imagWidth = newImage.size.width;
    NSInteger width = ((int)((nWidth + 7) / 8)) * 8;
    CGSize size = CGSizeMake(width, imgHeight * width / imagWidth);
    UIImage *scaled = [ImageTranster imgWithImage:newImage
                                 scaledToFillSize:size];

    unsigned char *graImage = [ImageTranster imgToGreyImage:scaled];
    unsigned char *formatedData =
        [ImageTranster img_format_K_threshold:graImage
                                        width:size.width
                                       height:size.height];
    NSData *dataToPrint = [ImageTranster convertEachLinePixToCmd:formatedData
                                                          nWidth:size.width
                                                         nHeight:size.height
                                                           nMode:0];

    NSLog(@"dataToPrint %@", dataToPrint);
    dispatch_queue_t printQueue =
        dispatch_queue_create("com.zywell.printQueue", NULL);
    dispatch_async(printQueue, ^{
      [self.bleManager writeCommadnToPrinterWthitData:dataToPrint];
      [self.bleManager
          writeCommadnToPrinterWithData:[PosCommand
                                            selectCutPageModelAndCutpage:0]
                             completion:^(BOOL success) {
                               if (success) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                   resolve(@"Print_Success");
                                 });
                               }
                             }];
    });

  } @catch (NSException *e) {
    NSLog(@"ERROR IN PRINTING IMG: %@", [e callStackSymbols]);
  }
}

RCT_EXPORT_METHOD(disconnectBLE
                  : (NSString *)address resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
  CBPeripheral *peripheralToRemove = nil;
  NSLog(@"Bluetooth isconnected %@", self.connectedPeripherals);
  for (CBPeripheral *connectedPeripheral in self.connectedPeripherals) {
    if ([connectedPeripheral.identifier.UUIDString isEqualToString:address]) {
      peripheralToRemove = connectedPeripheral;
      break;
    }
  }

  if (peripheralToRemove) {
    [self.bleManager disconnectPeripheral:peripheralToRemove];
    [self.connectedPeripherals removeObject:peripheralToRemove];
    resolve(nil);
    NSLog(@"Bluetooth device with address %@ disconnected successfully.",
          address);
  } else {
    reject(@"DISCONNECT_ERROR", @"Device not found.", nil);
  }
}

RCT_EXPORT_METHOD(clearBufferNet : (NSString *)ip_address) {
  POSWIFIManager *wifiManager = wifiManagerDictionary[ip_address];
  if (!wifiManager) {
    NSLog(@"Printer is not connected");
    return;
  }

  [wifiManager POSClearBuffer];
}

RCT_EXPORT_METHOD(clearBufferBLE) { [self.bleManager ClearBuffer]; }

@end
