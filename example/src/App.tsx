import React, { useEffect, useRef } from 'react';
import {
  Button,
  Dimensions,
  Image,
  Platform,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { PERMISSIONS, requestMultiple } from 'react-native-permissions';
import ViewShot, { captureRef } from 'react-native-view-shot';
import ZywellPrinter, {
  PRINTER_TYPE,
  PRINT_MODE,
  clearBuffer,
  printPic,
} from 'react-native-zywell-thermal-printer';
import { Colors } from 'react-native/Libraries/NewAppScreen';

const printers: any[] = [
  // {
  //   address: 'FDD3B2FA-8D0E-23B2-8FE7-A035684B2315', // MP583
  //   type: PRINTER_TYPE.BLUETOOTH,
  //   copy: 1,
  //   size: 58,
  //   mode: PRINT_MODE.THERMAL
  // },
  // {
  //   address: '97B9F848-F452-31A1-AFF1-1ACFD356AF70', // SBH-K57
  //   type: PRINTER_TYPE.BLUETOOTH,
  //   copy: 1,
  //   size: 58,
  //   mode: PRINT_MODE.THERMAL
  // },
  // { address: '192.168.1.210', type: PRINTER_TYPE.NET, copy: 1, size: 80,
  //   mode: PRINT_MODE.THERMAL },
  { address: '192.168.0.43', type: PRINTER_TYPE.NET, copy: 1, size: 58,
    mode: PRINT_MODE.THERMAL },
   
];

const printersLabel = [
 { address: '192.168.2.203', type: PRINTER_TYPE.NET, copy: 1, size: 58,
    mode: PRINT_MODE.LABEL },
]

const App = () => {
  const refView = useRef<any>();
  const refStampView = useRef<any>();

  useEffect(() => {
    const requestBluetoothPermission = async () => {
      try {
        const status: any = await requestMultiple([
          PERMISSIONS.ANDROID.BLUETOOTH_SCAN,
          PERMISSIONS.ANDROID.BLUETOOTH_CONNECT,
          PERMISSIONS.ANDROID.BLUETOOTH_ADVERTISE,
          PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION,
        ]);
        if (
          ['granted', 'unavailable'].includes(
            status[PERMISSIONS.ANDROID.BLUETOOTH_CONNECT]
          ) &&
          ['granted', 'unavailable'].includes(
            status[PERMISSIONS.ANDROID.BLUETOOTH_SCAN]
          ) &&
          ['granted', 'unavailable'].includes(
            status[PERMISSIONS.ANDROID.BLUETOOTH_ADVERTISE]
          ) &&
          ['granted', 'unavailable'].includes(
            status[PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION]
          )
        ) {
          return true;
        }
      } catch (error) {
        return false;
      }
    };
    requestBluetoothPermission();
  }, []);

  const printMultipleTimes = async (printer: any, imagePath: string) => {
    const printTimes = Array(printer?.copy).fill(0);
    const nWidth = printer?.size === 80 ? 576 : 384;

    const printJobs = printTimes?.map(() =>
      printPic(
        printer?.address,
        imagePath,
        { size: 58, width: nWidth, mode: printer?.mode, is_disconnect: true },
        printer?.type
      )
    );
    Promise.all(printJobs);
  };

  const printFunction = async (listPrinter: any, ref: any) => {
    const imagePath = await captureRef(ref, { format: 'png', quality: 1 });

    try {
      if (Platform.OS === 'android') {
        const connectJob = listPrinter.map((printer: any) => {
          clearBuffer(printer?.address, printer?.type);
          if (printer?.type === PRINTER_TYPE.BLUETOOTH) {
            return ZywellPrinter.connectBLE(printer?.address).then((res: any) =>
              {
                console.log('DCM: ', res);
                setTimeout(() => {
                  printMultipleTimes(printer, imagePath);
                }, 500)
              }
            );
          }

          if (printer?.type === PRINTER_TYPE.NET) {
            return ZywellPrinter.connectNet(printer?.address).then(() =>
              printMultipleTimes(printer, imagePath)
            );
          }
        });
        
      } else {
        const blePrinters = listPrinter.filter(
          (printer: any) => printer.type === PRINTER_TYPE.BLUETOOTH
        );
       
        const lanPrinters = listPrinter.filter(
          (printer: any) => printer.type === PRINTER_TYPE.NET
        );

        const lanPrintJob = lanPrinters.map((printer: any) => {
          clearBuffer(printer?.address, printer?.type);
          return ZywellPrinter.connectNet(printer?.address).then(() =>
            printMultipleTimes(printer, imagePath)
          );
        });
        Promise.all(lanPrintJob);
        for (let i = 0; i < blePrinters.length; i++) {
          const printer = blePrinters[i];
          const nWidth = printer?.size === 80 ? 576 : 384;
          const address = printer.address;
          const printTimes = Array(printer?.copy).fill(0);
          console.log('current  printTimes', printTimes);

          try {
            await ZywellPrinter.connectBLE(address);
            await clearBuffer(address, printer?.type);
            await new Promise((resolve) => setTimeout(() => {}, 750));
            for (let time = 0; time < printTimes.length; time++) {
              await ZywellPrinter.printPicBLE(address, imagePath, {
                size: 58,
                width: nWidth,
              });
            }
          } catch (error) {}
        }
      }
    } catch (error) {
      console.log('current  error', error);
    }
  };

  const printLabel = () => printFunction(printersLabel, refStampView)
  const printBill = () => printFunction(printers, refView)

  return (
    <SafeAreaView style={Colors.lighter}>
      <StatusBar barStyle={'dark-content'} backgroundColor={Colors.lighter} />
      <ScrollView contentInsetAdjustmentBehavior="automatic">
        <View style={styles.mV12} />

        <View style={styles.pd12}>
          <Text style={styles.v1}>List Printer</Text>
          {printers.map((item) => (
            <Text key={item.address} style={[styles.size18, styles.clBlack]}>
              {item?.address}
            </Text>
          ))}
          <View style={{flexDirection: 'row', justifyContent: 'space-between'}}>
            <Button
            color={'#33991F'}
            onPress={printBill}
            title={'print bill'}
          />
          <Button
            color={'#33991F'}
            onPress={printLabel}
            title={'print stamp'}
          />
          </View>
        </View>

        <ViewShot style={styles.v0} ref={refStampView}>
          <Image
            resizeMode={Platform.OS === 'ios' ? 'contain' : 'center'}
            style={styles.wrapStamp}
            source={require('./images/stamp.png')}
          />
        </ViewShot>

        <ViewShot style={styles.v0} ref={refView}>
          <Image
            resizeMode={Platform.OS === 'ios' ? 'contain' : 'center'}
            style={styles.wrapImg}
            source={require('./images/80m.png')}
          />
        </ViewShot>
        
      </ScrollView>
    </SafeAreaView>
  );
};

export default App;

const styles = StyleSheet.create({
  clBlack: {
    color: 'black',
  },
  pd12: {
    padding: 12,
  },
  sCenter: {
    alignSelf: 'center',
  },
  aCenter: {
    alignItems: 'center',
  },
  wrapImg: {
    width: Dimensions.get('window').width - 32,
    height: 1000,
  },
  wrapStamp: {
    width: Dimensions.get('window').width,
    height: (Dimensions.get('window').width) * 3 / 5,
    backgroundColor: '#ffffff',
  },
  size18: {
    fontSize: 18,
  },
  mV12: {
    marginVertical: 12,
  },
  v0: {
    backgroundColor: '#ffffff',
  },
  v1: {
    color: '#000',
    fontSize: 18,
    fontWeight: '500',
  },
  v2: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 12,
  },
  input: {
    borderColor: '#bbb',
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginTop: 12,
    flex: 1,
    marginRight: 12,
    fontSize: 18,
  },
  sectionContainer: {
    marginTop: 32,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
  },
  highlight: {
    fontWeight: '700',
  },
});
