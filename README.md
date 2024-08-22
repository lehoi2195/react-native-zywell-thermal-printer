# react-native-zywell-thermal-printer

Native bridge for Zywell Thermal printer https://www.zywell.net/download

Compatible with thermal printers, Bluetooth printers, LAN printers, ...

Since this library serves personal purposes, there will not be many updates. If there are any updates, please create a pull request or an issue. Thank you.

## Installation

```sh
npm install react-native-zywell-thermal-printer
```

Add the following permissions to your `AndroidManifest.xml`:
```js
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
```
Please check for additional permissions required by the library.

https://www.npmjs.com/package/react-native-bluetooth-escpos-printer

https://www.npmjs.com/package/react-native-bluetooth-state-manager

https://github.com/HeligPfleigh/react-native-thermal-receipt-printer



## Usage

```js
import ZywellPrinter from 'react-native-zywell-thermal-printer';

// Connect to a Bluetooth printer
ZywellPrinter.connectBLE('00:11:22:33:FF:EE')
  .then(() => {
    console.log('Connected to Bluetooth printer');
  })
  .catch((error) => {
    console.error('Failed to connect to Bluetooth printer', error);
  });

// Connect to a network printer
ZywellPrinter.connectNet('192.168.xx.xxx')
  .then(() => {
    console.log('Connected to network printer');
  })
  .catch((error) => {
    console.error('Failed to connect to network printer', error);
  });

// Print an image
ZywellPrinter.printPic('00:11:22:33:FF:EE', 'path/to/image.png', { width: 200, height: 200 })
  .then(() => {
    console.log('Printed image');
  })
  .catch((error) => {
    console.error('Failed to print image', error);
  });

// Disconnect from a Bluetooth printer
ZywellPrinter.disconnectPort('00:11:22:33:FF:EE')
  .then(() => {
    console.log('Disconnected from Bluetooth printer');
  })
  .catch((error) => {
    console.error('Failed to disconnect from Bluetooth printer', error);
  });

// Disconnect from a network printer
ZywellPrinter.disconnectNet('192.168.xx.xxx')
  .then(() => {
    console.log('Disconnected from network printer');
  })
  .catch((error) => {
    console.error('Failed to disconnect from network printer', error);
  });
```


## API

### `connectBLE(address: string): Promise<void>`

Connect to a Bluetooth printer.

- `address`: The Bluetooth address of the printer.

### `connectNet(ip: string): Promise<void>`

Connect to a network printer.

- `ip`: The IP address of the printer.

### `printPic(address: string, imagePath: string, options: object): Promise<void>`

Print an image.

- `address`: The Bluetooth address of the printer.
- `imagePath`: The path to the image file.
- `options`: The printing options (e.g., width, height).

### `disconnectPort(address: string): Promise<void>`

Disconnect from a Bluetooth printer.

- `address`: The Bluetooth address of the printer.

### `disconnectNet(ip: string): Promise<void>`

Disconnect from a network printer.

- `ip`: The IP address of the printer.

Please read the code in `ZywellThermalPrinterPackage.java` and `ZywellThermalPrinter.mm` for more APIs provided by the package, or you can check the Example directory.

Ex functions such as: `printText`, `isConnect`, `readBuffer`, `clearBuffer`, `disconnectAll`, `print once`, and `print multiple`, ...


## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
