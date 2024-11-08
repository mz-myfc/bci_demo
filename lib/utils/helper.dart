import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'ble/cmd.dart';
import 'parse/bci_af_protocol_v1.0/bci_af_protocol_v1.0.dart';
import 'parse/bci_protocol_v1.4/bci_protocol_v1.4.dart';
import 'parse/bci_protocol_v1.5/bci_protocol_v1.5.dart';
import 'parse/bci_protocol_v2.0/bci_protocol_v2.0.dart';
import 'parse/bci_rr_af_protocol_v1.0/bci_rr_af_protocol_v1.0.dart';
import 'parse/bci_rr_protocol_v1.0/bci_rr_protocol_v1.0.dart';
import 'parse/berry_protocol_v1.4/berry_protocol_v1.4.dart';

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
  String sv = '--'; //Software Version
  String hv = '--'; //Hardware Version

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
    sv = '--';
    hv = '--';

    BciProtocolFiveBytes.instance.init();
    BciProtocolSixBytes.instance.init();
    BciRrProtocol.instance.init();
    BciAfProtocol.instance.init();
    BciRrAfProtocol.instance.init();
    BciProtocolSevenBytes.instance.init();
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
    _version(array);
    switch (model) {
      case Cmd.BCI:
        BciProtocolFiveBytes.instance.parse(array);
        break;
      case Cmd.BCI_BATTERY:
        BciProtocolSixBytes.instance.parse(array);
        break;
      case Cmd.BCI_RR:
        BciRrProtocol.instance.parse(array);
        break;
      case Cmd.BCI_AF:
        BciAfProtocol.instance.parse(array);
        break;
      case Cmd.BCI_RR_AF:
        BciRrAfProtocol.instance.parse(array);
        break;
      case Cmd.BCI_BM100A_I:
        BciProtocolSevenBytes.instance.parse(array);
        break;
      default:
        var berry = isBerry(array);
        if (berry) {
          BerryProtocol.instance.parse(array);
        } else {
          BciProtocolFiveBytes.instance.parse(array);
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
    //Handles characters that are not recognized by Bluetooth names
    deviceName = device.name.toStr;
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
    return device.id;
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
    return '--';
  }

  //Berry Protocol
  bool isBerry(List<int> data) {
    if (data.isEmpty || data.length < 2) return false;
    for (int i = 0; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xAA) {
        return true;
      }
    }
    return false;
  }

  //ASCII
  void _version(List<int> array) {
    if (array.isEmpty) return;
    var arr = array.sublist(2, array.length - 1);
    var ascii = String.fromCharCodes(arr).toStr;
    if (ascii.contains('SV')) {
      sv = ascii;
    }
    if (ascii.contains('HV')) {
      hv = ascii;
    }
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

extension MyString on String {
  String get toStr => codeUnits.contains(0)
      ? String.fromCharCodes(
          Uint8List.fromList(codeUnits.sublist(0, codeUnits.indexOf(0))),
        )
      : this;
}
