# 提示
2018-2-1

感谢大家的反馈，这个是nRF-Toolbox停更OC版本之前的项目，3.0版本，最新的nRF是4.4.4，我给挪过来了。其中用于DFU升级的库我前几天更新了下，是较新的版本，但仍可能会存在隐藏问题。
这个项目的目的是为不熟悉swift的开发者提供一个参考，但我也能力有限，另一方面感觉也没有必要，持续跟进对应swift版本的更新。所以遇到开发问题，应该首先考虑版本差异，其次参考官网的做法[IOS-nRF-Toolbox](https://github.com/NordicSemiconductor/IOS-nRF-Toolbox)，谢谢大家。

---
2019-1-7

* 更新了[iOS-DFU-Library](https://github.com/NordicSemiconductor/IOS-Pods-DFU-Library)，目前版本是4.2.1。
* 在Xcode10.1上跑了下，没有问题。
* 把一些官方不再推荐的方法换成了推荐方法。

---
2019-7-14
* 更新了iOS-DFU-Library，目前版本是4.4.2
* 在Xcode10.2.1验证过

针对之前常出的这种问题：
```ruby
dyld: Library not loaded: @rpath/libswiftCore.dylib
Referenced from: /private/var/containers/Bundle/Application/CDB2F4ED-C49C-4303-BE1F-5D9D990380F3/nRF Toolbox.app/Frameworks/Zip.framework/Zip
Reason: image not found
```
均是由Swift库版本不一致引起的，`iOSDFULibrary`目前已经支持到Swift 5，所以我们应该升级一下版本。为了方便使用，我将`Carthage`集成到了项目里，如果以后需要再升级，更新`Cartfile`文件里的版本号，执行更新命令：
```
carthage update --platform iOS
```



# IOS-nRF-Toolbox

The nRF Toolbox is a container app that stores your Nordic Semiconductor apps for Bluetooth Smart in one location. 

The current version is 3.0. 

New in 3.0 version:
* The application uses DFU Library, instead of having it's own implementation. See [IOS-DFU-Library](https://github.com/NordicSemiconductor/IOS-DFU-Library).

New in 2.5 version:
* Refreshed Look & Feel
* Better user experience in DFU and UART profiles
* Bug fixes

It contains applications demonstrating Bluetooth Smart profiles: 
* **Cycling Speed and Cadence**, 
* **Running Speed and Cadence**, 
* **Heart Rate Monitor**, 
* **Blood Pressure Monitor**, 
* **Health Thermometer Monitor**, 
* **Glucose Monitor**,
* **Proximity Monitor**. 

### Device Firmware Update

The **Device Firmware Update (DFU)** profile allows you to update the application, bootloader and/or the Soft Device image over-the-air (OTA). It is compatible with Nordic Semiconductor nRF5x devices that have the S-Series SoftDevice and bootloader enabled. From version 1.5 onward, the nRF Toolbox has allowed to send the required init packet. More information about the init packet may be found here: [init packet handling](https://github.com/NordicSemiconductor/nRF-Master-Control-Panel/tree/master/init%20packet%20handling).

The nRF Toolbox 3.0 is using the DFULibrary framework, available here: [IOS-DFU-Library](https://github.com/NordicSemiconductor/IOS-DFU-Library). The library is required to compile the project. Please, follow the steps in this repository to add it to the project.

The DFU has the following features:
- Scans for devices that are in DFU mode.
- Connects to devices in DFU mode and uploads the selected firmware (Softdevice, Bootloader and/or application).
- Allows HEX or BIN file upload through your phone or tablet.
- Allows to update a Softdevice and/or bootloader and application from ZIP automatically.
- Pause, resume, and cancel file uploads.
- Includes pre-installed examples that consist of the Bluetooth Smart heart rate service and running speed and cadence service.

### Note
- iPhone 4S or newer is required.
- iPad 3 or newer is required.
- Compatible with nRF5x devices with S-Series Softdevice and DFU Bootloader flashed.
- nRF51 and nRF52 Development kits can be ordered from http://www.nordicsemi.com/eng/Buy-Online.
- The SDK and SoftDevices are available online at http://developer.nordicsemi.com.
