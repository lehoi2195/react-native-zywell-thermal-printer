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
import ZywellPrinter from 'react-native-zywell-thermal-printer';
import { Colors } from 'react-native/Libraries/NewAppScreen';

const printers: any[] = [
  // { address: 'DC:0D:51:C4:40:A0', type: 'BLE', copy: 2 },
  // { address: 'DC:0D:51:08:14:30', type: 'BLE', copy: 1 },
  // { address: '10:22:33:12:85:19', type: 'BLE', copy: 1 },
  { address: '192.168.0.43', type: 'LAN', copy: 1 },
  // { address: '192.168.0.201', type: 'LAN', copy: 1 },
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
        console.log('current  status', status);
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

  const connectPrinter = async () => {
    try {
      if (printers[0]?.type === 'BLE') {
        await ZywellPrinter.connectBT(printers[0]?.address);
      }
      if (printers[0]?.type === 'LAN') {
        await ZywellPrinter.connectNet(printers[0].address);
      }
    } catch (error) {
      console.log('current  error', error);
    }
  };

  const printFunction = async () => {
    const uri = await captureRef(refView, { format: 'png', quality: 1 });
    try {
      const connectJob = printers.map(async (printer) => {
        ZywellPrinter.disconnectPort(printer.address);
        setTimeout(() => {
          if (printer?.type === 'BLE') {
            ZywellPrinter.connectBT(printer.address).then(() =>
              printReceiptMultipleTimes(printer, uri)
            );
          }

          if (printer?.type === 'LAN') {
            ZywellPrinter.connectNet(printer.address).then(() =>
              printReceiptMultipleTimes(printer, uri)
            );
          }
        }, 500);
      });

      await Promise.all(connectJob);
    } catch (error) {}
  };

  const printSample = async () => {
    const uri = await captureRef(refView, { format: 'png', quality: 1 });
    printReceiptMultipleTimes(printers[0], `${uri}`);
  };

  const printReceiptMultipleTimes = async (printer: any, uri: string) => {
    const printTimes = Array(printer.copy).fill(0);
    const printJobs = printTimes.map(() =>
      ZywellPrinter.printPic(printer.address, uri)
    );
    Promise.all(printJobs);
  };

  return (
    <SafeAreaView style={Colors.lighter}>
      <StatusBar barStyle={'dark-content'} backgroundColor={Colors.lighter} />
      <ScrollView contentInsetAdjustmentBehavior="automatic">
        <View>
          <View style={[styles.v2, styles.aCenter]}>
            <Text style={styles.size18}>{printers[0]?.address}</Text>
            <Button color="green" onPress={connectPrinter} title={'connect'} />
          </View>
          <View style={styles.sCenter}>
            <Button color="red" onPress={printSample} title="Print Sample" />
          </View>
        </View>

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
    height: 500,
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
