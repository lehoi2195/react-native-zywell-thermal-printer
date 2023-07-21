// ZywellThermalPrinter.m

#import "ZywellThermalPrinter.h"
#import "POSSDK.h"
#import "PosCommand.h"
#import "TscCommand.h"
#import "BLEManager.h"
#import "ImageTranster.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ZywellThermalPrinter () <BLEManagerDelegate, POSWIFIManagerDelegate>

@property (nonatomic, strong) POSWIFIManager *wifiManager;
@property (strong, nonatomic) BLEManager *bleManager;

@end

@implementation ZywellThermalPrinter
NSMutableDictionary<NSString *, POSWIFIManager *> *wifiManagerDictionary;

RCT_EXPORT_MODULE();


-(POSWIFIManager *)wifiManager
{
    if (!_wifiManager)
    {
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

- (instancetype)init
{
    if (self = [super init]) {
        wifiManagerDictionary = [NSMutableDictionary dictionary];
        _bleManager.delegate = self;
    }
    return self;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (void)zyWellConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"OK=========================== %@", peripheral);
    if (peripheral != nil) {
        [self.bleManager connectPeripheral:peripheral];
        self.bleManager.writePeripheral = peripheral;
    }
}


RCT_EXPORT_METHOD(connectNet:(NSString *)ip_address resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    POSWIFIManager *wifiManager = wifiManagerDictionary[ip_address];
    if (!wifiManager) {
        wifiManager = [[POSWIFIManager alloc] init];
        wifiManager.delegate = self;
        wifiManagerDictionary[ip_address] = wifiManager;
    }

    [wifiManager POSDisConnect];
    [wifiManager POSConnectWithHost:ip_address port:9100 completion:^(BOOL isConnect) {
        if (isConnect) {
            resolve(@(YES));
            NSLog(@"Connect Success");
        } else {
            NSError *error = [NSError errorWithDomain:@"ZywellPrinterErrorDomain" code:1001 userInfo:@{ NSLocalizedDescriptionKey: @"Connection failed" }];
            reject(@"connect_failed", @"Failed to connect to the printer", error);
        }
    }];
}


RCT_EXPORT_METHOD(printPic:(NSString *)ipAddress imagePath:(NSString *)imagePath printerOptions:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    @try {

      POSWIFIManager *wifiManager = wifiManagerDictionary[ipAddress];
      if (!wifiManager) {
          NSError *error = [NSError errorWithDomain:@"ZywellModuleErrorDomain" code:1002 userInfo:@{ NSLocalizedDescriptionKey: @"Printer is not connected" }];
          reject(@"printer_not_connected", @"Printer is not connected", error);
          return;
      }

      int nWidth = [options[@"width"] intValue];

      NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
      CIImage *inputImage = [CIImage imageWithContentsOfURL:imageURL];

      // Create a black and white filter
      CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
      [filter setValue:inputImage forKey:kCIInputImageKey];
      [filter setValue:@(0.0) forKey:kCIInputSaturationKey]; // Set saturation to 0 to remove color
      BOOL isDisconnect = [options[@"is_disconnect"] boolValue]; // Get the boolean value from options dictionary

      // Apply the filter and get the output image
      CIImage *outputImage = [filter outputImage];

      // Create a CIContext to render the output image
      CIContext *context = [CIContext context];
      CGImageRef outputCGImage = [context createCGImage:outputImage fromRect:[outputImage extent]];

      // Convert the output CGImage to a UIImage
      UIImage *newImage = [UIImage imageWithCGImage:outputCGImage];

      NSInteger imgHeight = newImage.size.height;
      NSInteger imagWidth = newImage.size.width;
      NSInteger width =  ((int)((nWidth + 7)/8))*8;
      CGSize size = CGSizeMake(width, imgHeight*width/imagWidth);
      UIImage *scaled = [ImageTranster imgWithImage:newImage scaledToFillSize:size];

      unsigned char * graImage = [ImageTranster imgToGreyImage:scaled];
      unsigned char * formatedData = [ImageTranster img_format_K_threshold:graImage width:size.width height:size.height];
      NSData *dataToPrint = [ImageTranster convertEachLinePixToCmd:formatedData nWidth:size.width nHeight:size.height nMode:0];

      [wifiManager POSWriteCommandWithData:dataToPrint];
      [wifiManager POSWriteDataWithCallback:[PosCommand selectCutPageModelAndCutpage:0] completion:^(BOOL success) {
          if (success && isDisconnect) {
            NSLog(@"Printing Successs");
            dispatch_async(dispatch_get_main_queue(), ^{
                [wifiManager POSDisConnect];
            });
          }
        }
      ];


    } @catch(NSException *e){
        NSLog(@"ERROR IN PRINTING IMG: %@",[e callStackSymbols]);
    }
}

RCT_EXPORT_METHOD(disconnectNet:(NSString *)ipAddress) {
    POSWIFIManager *wifiManager = wifiManagerDictionary[ipAddress];
    if (wifiManager) {
        [wifiManager POSDisConnect];
        [wifiManagerDictionary removeObjectForKey:ipAddress];
    }
}

RCT_EXPORT_METHOD(connectBLE:(NSString *)address resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
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
        [self.bleManager connectPeripheral:peripheral completion:^(BOOL isConnected) {
            NSLog(@"=========connectPeripheral peripheral %@", peripheral);
            if (isConnected) {
                self.bleManager.writePeripheral = peripheral;
                resolve(address);
            } else {
                NSError *error = [NSError errorWithDomain:@"RCTZywellThermalPrinterErrorDomain" code:1002 userInfo:@{ NSLocalizedDescriptionKey: @"Failed to connect to the peripheral" }];
                reject(@"failed_to_connect", @"Failed to connect to the peripheral", error);
            }
        }];
    } else {
        __block BOOL stopScanning = NO;
        [self.bleManager startScanWithInterval:3 completion:^(NSArray *peripherals) {
            if (stopScanning) {
                return;
            }

            CBPeripheral *scannedPeripheral = nil;
            for (CBPeripheral *discoveredPeripheral in peripherals) {
                if ([discoveredPeripheral.identifier.UUIDString isEqualToString:address]) {
                    scannedPeripheral = discoveredPeripheral;
                    foundPeripheral = YES;
                    break;
                }
            }

            if (scannedPeripheral) {

                [self.bleManager.peripherals addObject:scannedPeripheral];
                [self.bleManager connectPeripheral:scannedPeripheral completion:^(BOOL isConnected) {
                    if (isConnected) {
                        NSLog(@"=========connectPeripheral scannedPeripheral %@", scannedPeripheral);
                        stopScanning = YES;
                        [self.bleManager stopScan];
                        self.bleManager.writePeripheral =scannedPeripheral;
                        resolve(address);
                    }
                }];
            }
        }];
    }
}

RCT_EXPORT_METHOD(printPicBLE:(NSString *)ipAddress imagePath:(NSString *)imagePath printerOptions:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        int nWidth = [options[@"width"] intValue];
        NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
        CIImage *inputImage = [CIImage imageWithContentsOfURL:imageURL];

        // Create a black and white filter
        CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
        [filter setValue:inputImage forKey:kCIInputImageKey];
        [filter setValue:@(0.0) forKey:kCIInputSaturationKey]; // Set saturation to 0 to remove color

        // Apply the filter and get the output image
        CIImage *outputImage = [filter outputImage];

        // Create a CIContext to render the output image
        CIContext *context = [CIContext context];
        CGImageRef outputCGImage = [context createCGImage:outputImage fromRect:[outputImage extent]];

        // Convert the output CGImage to a UIImage
        UIImage *newImage = [UIImage imageWithCGImage:outputCGImage];

        // Create a new UIImage object
        NSInteger imgHeight = newImage.size.height;
        NSInteger imagWidth = newImage.size.width;
        NSInteger width =  ((int)((nWidth + 7)/8))*8;
        CGSize size = CGSizeMake(width, imgHeight*width/imagWidth);
        UIImage *scaled = [ImageTranster imgWithImage:newImage scaledToFillSize:size];

        unsigned char * graImage = [ImageTranster imgToGreyImage:scaled];
        unsigned char * formatedData = [ImageTranster img_format_K_threshold:graImage width:size.width height:size.height];
        NSData *dataToPrint = [ImageTranster convertEachLinePixToCmd:formatedData nWidth:size.width nHeight:size.height nMode:0];

        NSLog(@"dataToPrint %@", dataToPrint);
        dispatch_queue_t printQueue = dispatch_queue_create("com.zywell.printQueue", NULL);
        dispatch_async(printQueue, ^{
            [self.bleManager writeCommadnToPrinterWthitData:dataToPrint];
            [self.bleManager writeCommadnToPrinterWithData:[PosCommand selectCutPageModelAndCutpage:0] completion:^(BOOL success) {
                if (success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        resolve(@"Print_Success");
                    });
                }
            }];
        });

    } @catch(NSException *e){
        NSLog(@"ERROR IN PRINTING IMG: %@",[e callStackSymbols]);
    }
}


RCT_EXPORT_METHOD(disconnectBLE:(NSString *)address
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"Trying to disconnect device with address: %@", address);
    CBPeripheral *peripheral = nil;
    NSMutableArray *foundDevice = self.bleManager.peripherals;

    for (CBPeripheral *peripheralObj in foundDevice) {
        if ([peripheralObj.identifier.UUIDString isEqualToString:address]) {
            peripheral = peripheralObj;
            break;
        }
    }

    if (peripheral) {
        [self.bleManager disconnectPeripheral:peripheral];
        resolve(nil);
        NSLog(@"Bluetooth device with address %@ disconnected successfully.", address);
    } else {
        reject(@"DISCONNECT_ERROR", @"Device not found.", nil);
    }
}


RCT_EXPORT_METHOD(clearBufferNet:(NSString *)ip_address)
{
  POSWIFIManager *wifiManager = wifiManagerDictionary[ip_address];
  if (!wifiManager) {
    NSLog(@"Printer is not connected");
    return;
  }

  [wifiManager POSClearBuffer];
}

RCT_EXPORT_METHOD(clearBufferBLE)
{
  [self.bleManager ClearBuffer];
}

@end
