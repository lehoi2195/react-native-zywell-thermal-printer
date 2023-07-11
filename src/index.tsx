import { NativeModules } from 'react-native';

const { ZywellThermalPrinterModule: ZywellPrinter } = NativeModules;

// example
export function multiply(a: number, b: number): Promise<number> {
  return ZywellPrinter.multiply(a, b);
}

export default ZywellPrinter;
