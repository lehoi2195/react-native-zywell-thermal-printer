import { NativeModules, Platform } from 'react-native';

const { ZywellThermalPrinter: ZywellPrinter } = NativeModules;
export const PRINTER_TYPE = {
  NET: 'IP',
  BLUETOOTH: 'BLUETOOTH',
};

export const PRINT_MODE = {
  THERMAL: 'THERMAL',
  LABEL: 'LABEL'
}

export function clearBuffer(address: string, type: string) {
  if (Platform.OS === 'ios') {
    if (type === PRINTER_TYPE.NET) {
      ZywellPrinter.clearBufferNet(address);
    }
    if (type === PRINTER_TYPE.BLUETOOTH) {
      ZywellPrinter.clearBufferBLE();
    }
  }

  if (Platform.OS === 'android') {
    ZywellPrinter.clearBuffer(address);
  }
}

export function disconnectAddress(address: string, type: string) {
  if (Platform.OS === 'ios') {
    if (type === PRINTER_TYPE.NET) {
      ZywellPrinter.disconnectNet(address);
    }
    if (type === PRINTER_TYPE.BLUETOOTH) {
      ZywellPrinter.disconnectBLE(address);
    }
  }

  if (Platform.OS === 'android') {
    ZywellPrinter.disconnectPort(address);
  }
}

export function printPic(
  address: string,
  imagePath: string,
  opts: { size: number; width: number, mode: string, is_disconnect: boolean },
  type: string
) {
  if (type === PRINTER_TYPE.BLUETOOTH && Platform.OS === 'ios') {
    return ZywellPrinter.printPicBLE(address, imagePath, opts);
  }

  ZywellPrinter.printPic(address, imagePath, opts);
}

export function connectBLE(address: string) {
  return new Promise((resolve, reject) => {
    ZywellPrinter.connectBLE(address)
      .then(() => {
        resolve(address);
      })
      .catch(() => reject('ERROR_CONNECT'));
  });
}

export default ZywellPrinter;
