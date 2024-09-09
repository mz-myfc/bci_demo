import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'cmd.dart';
import 'parse/bci_bm1000_i.dart';
import 'parse/bci_eight_bytes.dart';
import 'parse/bci_five_bytes.dart';
import 'parse/bci_nine_bytes.dart';
import 'parse/bci_seven_bytes.dart';
import 'parse/bci_six_bytes.dart';
import 'parse/berry_protocol.dart';

/*
 * @description 
 * @author zl
 * @date 2024/9/6 13:46
 */
class Helper extends ChangeNotifier {
  static final Helper h = Helper._();

  Helper._();

  int spo2 = 0; //Oxygen Saturation
  int pr = 0; //Pulse Rate
  double pi = 0.0; //Perfusion Index
  int si = 0; //Signal Index
  int rr = 0; //Respiratory Rate
  int af = 0; //Atrial Fibrillation
  int battery = 0;
  int heart = 0; // Pulse Sounds(Heart Beat / Buzzer)
  int wave = 0; // Volumetric Waves(Pulse Wave)

  String model = '--';
  String deviceName = '--';
  String deviceId = '--';
  String packetFreq = '--'; //Packets Frequency

  Timer? timer;

  void init() {
    spo2 = 0;
    pr = 0;
    pi = 0.0;
    si = 0;
    rr = 0;
    af = 0;
    battery = 0;
    model = '--';
    deviceName = '--';
    deviceId = '--';
    packetFreq = '--';

    BciFiveBytes.instance.init();
    BciSixBytes.instance.init();
    BciSevenBytes.instance.init();
    BciEightBytes.instance.init();
    BciNineBytes.instance.init();
    BciBm1000I.instance.init();
    BerryProtocol.instance.init();

    refresh();
  }

  //Start refreshing
  void startTimer() {
    stopTimer();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  //Stop the timer
  void stopTimer() {
    timer?.cancel();
    timer = null;
  }

  //Notification refresh
  void refresh() => notifyListeners();

  //Parse Data
  void parse(List<int> array) {
    switch (model) {
      case Cmd.BCI:
        BciFiveBytes.instance.parse(array);
        break;
      case Cmd.BCI_BATTERY:
        BciSixBytes.instance.parse(array);
        break;
      case Cmd.BCI_RR:
        BciSevenBytes.instance.parse(array);
        break;
      case Cmd.BCI_AF:
        BciEightBytes.instance.parse(array);
        break;
      case Cmd.BCI_RR_AF:
        BciNineBytes.instance.parse(array);
        break;
      case Cmd.BCI_BM100A_I:
        BciBm1000I.instance.parse(array);
        break;
      default:
        if (array.length >= 2) {
          if (array[0] == 0xFF && array[1] == 0xAA) {
            BerryProtocol.instance.parse(array);
          } else {
            BciFiveBytes.instance.parse(array);
          }
        }
        break;
    }
  }

  /*
   * spo2: Blood Oxygen
   * pr: Pulse Rate
   * pi: Perfusion Index
   * si: Signal Index
   * heart: Pulse Sounds(Heart Beat / Buzzer)
   * wave: Volumetric Waves(Pulse Wave)
   * rr: Respiratory Rate
   * af: Atrial Fibrillation
   * battery: Battery Level
   */
  void readParseData(int spo2, int pr, double pi, int si, int heart, int wave,
      int rr, int af, int battery) {

    if (spo2 < 35 || spo2 > 100) spo2 = 0;
    if (pr < 25 || pr > 250) pr = 0;
    //Reset PI and SI based on blood oxygen pulse rate
    if (spo2 <= 0 && pr <= 0) {
      pi = 0;
      si = 0;
    }
    this.spo2 = spo2;
    this.pr = pr;
    this.pi = pi;
    this.si = si;
    this.rr = rr;
    this.af = af;
    this.heart = heart;
    this.wave = wave;
    this.battery = battery;
  }

  void setDeviceInfo(DiscoveredDevice device) {
    deviceName = _setBleName(device.name);
    deviceId = _getMac(device);
    model = _deviceModel(device);
    refresh();
  }

  ///Get Mac, iOS compatible
  String _getMac(DiscoveredDevice device) {
    var manufacturerData = device.manufacturerData.toList();
    if (manufacturerData.length >= 8) {
      var mac = manufacturerData
          .sublist(2, 8)
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .toList();
      return mac.toParts;
    }
    return device.id.startsWith('00:A0:50') ? device.id : '--';
  }

  //Handles characters that are not recognized by Bluetooth names
  String _setBleName(String name) {
    if (name.codeUnits.contains(0)) {
      return String.fromCharCodes(
        Uint8List.fromList(name.codeUnits.sublist(0, name.codeUnits.indexOf(0))),
      );
    }
    return name;
  }

  //Device model
  String _deviceModel(DiscoveredDevice device) {
    var manufacturerData = device.manufacturerData.toList();
    if (manufacturerData.length >= 11) {
      var model = manufacturerData
          .sublist(manufacturerData.length - 3)
          .map((e) => e.toRadixString(16).toString().padLeft(2, '0'))
          .toList();
      return model.toParts;
    }
    return '';
  }
}

extension Format on num {
  String get intVal => this > 0 ? '$this' : '--';

  String get asFixed => this > 0 ? toStringAsFixed(1) : '--';

  double get toDou => this > 0 ? double.parse(toStringAsFixed(1)) : 0.0;

  String get battery => this > 0 ? '$this%' : '--';
}

extension MyListFormat on List {
  String get toParts =>
      isNotEmpty ? map((e) => e.toString().padLeft(2, '0')).join(':') : '';
}
