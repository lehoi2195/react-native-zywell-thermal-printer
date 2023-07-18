import React, { useEffect, useRef } from 'react';
import {
  Button,
  Dimensions,
  Image,
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
  clearBuffer,
  printPic,
} from 'react-native-zywell-thermal-printer';
import { Colors } from 'react-native/Libraries/NewAppScreen';

const printers: any[] = [
  // {
  //   address: 'FDD3B2FA-8D0E-23B2-8FE7-A035684B2315',
  //   type: PRINTER_TYPE.BLUETOOTH,
  //   copy: 1,
  //   size: 58,
  // },
  {
    address: '16B5C92F-5324-94D9-2523-E0825521C49B',
    type: PRINTER_TYPE.BLUETOOTH,
    copy: 1,
    size: 58,
  },
  // { address: '192.168.1.210', type: PRINTER_TYPE.NET, copy: 1, size: 80 },
  // { address: '192.168.0.43', type: PRINTER_TYPE.NET, copy: 1, size: 58 },
];

const App = () => {
  const refView = useRef<any>();

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
    console.log('current  printer', printer);
    const printTimes = Array(printer?.copy).fill(0);
    const nWidth = printer?.size === 80 ? 576 : 384;

    const printJobs = printTimes?.map(() =>
      printPic(
        printer?.address,
        imagePath,
        { size: 58, width: nWidth },
        printer?.type
      )
    );
    Promise.all(printJobs);
  };

  const printFunction = async () => {
    const imagePath = await captureRef(refView, { format: 'png', quality: 1 });
    try {
      const connectJob = printers.map((printer) => {
        clearBuffer(printer?.address, printer?.type);
        if (printer?.type === PRINTER_TYPE.BLUETOOTH) {
          return ZywellPrinter.connectBT(printer?.address).then(() => {
            console.log(
              '==========================> current  connect OKKKKK printer',
              printer?.address
            );
            return printMultipleTimes(printer, imagePath);
          });
        }

        if (printer?.type === PRINTER_TYPE.NET) {
          return ZywellPrinter.connectNet(printer?.address).then(() =>
            printMultipleTimes(printer, imagePath)
          );
        }
      });
      Promise.all(connectJob);
    } catch (error) {
      console.log('current  error', error);
    }
  };

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
          <Button
            color={'#33991F'}
            onPress={printFunction}
            title={'print multiple'}
          />
        </View>

        <ViewShot style={styles.v0} ref={refView}>
          <Image
            resizeMode={'cover'}
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
  size18: {
    fontSize: 18,
  },
  mV12: {
    marginVertical: 12,
  },
  v0: {
    padding: 16,
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
