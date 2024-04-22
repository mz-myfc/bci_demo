import 'dart:async';

import 'package:bci_demo/utils/cmd.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sprintf/sprintf.dart';

/*
 * @description Helper
 * @author zl
 * @date 2023/11/30 12:54
 */
class Helper extends ChangeNotifier {
  static final Helper h = Helper._();

  Helper._();

  List<int> bufferArray = [];
  int spo2 = 0; //Oxygen Saturation
  int pr = 0; //Pulse Rate
  double pi = 0.0; //Perfusion index
  int si = 0; //Signal Index
  int rr = 0; //Respiratory rate
  int af = 0; //Atrial fibrillation

  String model = Cmd.BCI;
  int battery = 0;
  String deviceName = '--';
  String deviceId = '--';

  Timer? timer;

  void init() {
    bufferArray = [];
    spo2 = 0;
    pr = 0;
    pi = 0.0;
    si = 0;
    rr = 0;
    af = 0;
    battery = 0;
    model = Cmd.BCI;
    deviceName = '--';
    deviceId = '--';
    refresh();
  }

  //Bluetooth data analysis
  void analysis(List<int> array) { 
    switch (model) {
      case Cmd.BCI:
        _analysisBci(array);
        break;
      case Cmd.BCI_BATTERY:
        _analysisBciBattery(array);
        break;
      case Cmd.BCI_RR:
        _analysisBciRR(array);
        break;
      case Cmd.BCI_AF:
        _analysisBciAf(array);
        break;
      case Cmd.BCI_RR_AF:
        _analysisBciRrAf(array);
        break;
      case Cmd.BCI_BM100A_I:
        _animalBciBm1000AI(array);
        break;
      default:
        _analysisBci(array);
        break;
    }
  }

  //Notification refresh
  void refresh() => notifyListeners();

  //Start the BCI refresh interface
  void startTimer() {
    stopTimer();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      refresh();
    });
  }

  //Stop the timer
  void stopTimer() {
    timer?.cancel();
    timer = null;
  }

  void setDeviceInfo(DiscoveredDevice device){
    deviceName = _setBleName(device.name);
    deviceId = _getMac(device);
    model = _deviceModel(device);
    refresh();
  }

  //Device model
  String _deviceModel(DiscoveredDevice device) {
    var manufacturerData = device.manufacturerData.toList();
    if (manufacturerData.length >= 11) {
      var model = manufacturerData.reversed
          .toList()
          .sublist(0, 3)
          .reversed
          .toList()
          .map((e) => e.toRadixString(16).toString().padLeft(2, '0'))
          .toList();
      return model.isNotEmpty ? sprintf('%s:%s:%s', model).toString() : Cmd.BCI;
    }
    return Cmd.BCI;
  }

  ///Get Mac, iOS compatible
  String _getMac(DiscoveredDevice device) {
    var manufacturerData = device.manufacturerData.toList();
    if (manufacturerData.length >= 8) {
      var mac = manufacturerData
          .sublist(2, 8)
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .toList();
      return sprintf('%s:%s:%s:%s:%s:%s', mac).toString();
    }
    return device.id.startsWith('00:A0:50') ? device.id : '--';
  }


  //Handles characters that are not recognized by Bluetooth names
  String _setBleName(String name) {
    try {
      if (name.codeUnits.contains(0)) {
        return String.fromCharCodes(Uint8List.fromList(
            name.codeUnits.sublist(0, name.codeUnits.indexOf(0))));
      } else {
        return name;
      }
    } catch (_) {}
    return '--';
  }

  //PI
  double _getPi(int value) {
    switch (value & 0x0F) {
      case 0:
        return 0.1;
      case 1:
        return 0.2;
      case 2:
        return 0.4;
      case 3:
        return 0.7;
      case 4:
        return 1.4;
      case 5:
        return 2.7;
      case 6:
        return 5.3;
      case 7:
        return 10.3;
      case 8:
        return 20.0;
      default:
        return 0;
    }
  }

  //SI
  int _getSi(double pi) {
    if (pi >= 0.1 && pi < 0.2) {
      return 0;
    } else if (pi >= 0.2 && pi < 0.4) {
      return 1;
    } else if (pi >= 0.4 && pi < 0.7) {
      return 2;
    } else if (pi >= 0.7 && pi < 1.4) {
      return 3;
    } else if (pi >= 1.4 && pi < 2.7) {
      return 4;
    } else if (pi >= 2.7 && pi < 5.3) {
      return 5;
    } else if (pi >= 5.3 && pi < 10.3) {
      return 6;
    } else if (pi >= 10.3 && pi < 20.0) {
      return 7;
    } else if (pi >= 20.0) {
      return 8;
    } else {
      return 0;
    }
  }
  
  void _analysisBci(List<int> array) {
    bufferArray += array;
    var i = 0; //Current index
    var validIndex = 0; //Valid indexes
    var maxCount = bufferArray.length - 5; //Leave at least enough room for a minimum set of data
    while (i <= maxCount) {
      if (bufferArray[i] >= 128 &&
          bufferArray[i + 1] < 128 &&
          bufferArray[i + 2] < 128 &&
          bufferArray[i + 3] < 128 &&
          bufferArray[i + 4] < 128) {
        int heart = bufferArray[i];
        double pi = _getPi(heart);
        int si = _getSi(pi);
        int wave = bufferArray[i + 1];
        int pr = bufferArray[i + 2] >= 64 ? bufferArray[i + 3] + 128 : bufferArray[i + 3];
        int spo2 = bufferArray[i + 4];

        //Read the data
        readData(spo2, pr, pi, si, heart, wave, 0, 0, -1);

        i += 5; //The data header is successfully matched, and a group of data is skipped
        validIndex = i;
        continue;
      }
      i += 1; //If the data header matching fails, skip one
      validIndex = i;
    }
    //The array before the valid index belongs to the scanned and is not needed, and it is directly emptied
    bufferArray = bufferArray.sublist(validIndex);
  }

  void _analysisBciBattery(List<int> array) {
    bufferArray += array;
    var i = 0;
    var validIndex = 0;
    var maxCount = bufferArray.length - 6;
    while (i <= maxCount) {
      if (bufferArray[i] >= 128 &&
          bufferArray[i + 1] < 128 &&
          bufferArray[i + 2] < 128 &&
          bufferArray[i + 3] < 128 &&
          bufferArray[i + 4] < 128 &&
          bufferArray[i + 5] < 128) {
        int heart = bufferArray[i];
        double pi = _calculatePi(heart, bufferArray[i + 2]);
        int si = _getSi(pi);
        int wave = bufferArray[i + 1];
        int pr = bufferArray[i + 2] >= 64 ? bufferArray[i + 3] + 128 : bufferArray[i + 3];
        int spo2 = bufferArray[i + 4];
        int battery = bufferArray[i + 5];

        readData(spo2, pr, pi, si, heart, wave, 0, 0, battery);

        i += 6;
        validIndex = i;
        continue;
      }
      i += 1;
      validIndex = i;
    }
    bufferArray = bufferArray.sublist(validIndex);
  }


  void _analysisBciRR(List<int> array) {
    bufferArray += array;
    var i = 0;
    var validIndex = 0;
    var maxCount = bufferArray.length - 7;
    while (i <= maxCount) {
      if (bufferArray[i] >= 128 &&
          bufferArray[i + 1] < 128 &&
          bufferArray[i + 2] < 128 &&
          bufferArray[i + 3] < 128 &&
          bufferArray[i + 4] < 128 &&
          bufferArray[i + 5] < 128 &&
          bufferArray[i + 6] < 128) {
        int heart = bufferArray[i];
        double pi = _calculatePi(heart, bufferArray[i + 2]);
        int si = _getSi(pi);
        int wave = bufferArray[i + 1];
        int pr = bufferArray[i + 2] >= 64 ? bufferArray[i + 3] + 128 : bufferArray[i + 3];
        int spo2 = bufferArray[i + 4];
        int battery = bufferArray[i + 5];
        int rr = bufferArray[i + 6];

        readData(spo2, pr, pi, si, heart, wave, rr, 0, battery);

        i += 7;
        validIndex = i;
        continue;
      }
      i += 1;
      validIndex = i;
    }
    bufferArray = bufferArray.sublist(validIndex);
  }

  void _analysisBciAf(List<int> array) {
    bufferArray += array;
    var i = 0;
    var validIndex = 0;
    var maxCount = bufferArray.length - 8;
    while (i <= maxCount) {
      if (bufferArray[i] >= 128 &&
          bufferArray[i + 1] < 128 &&
          bufferArray[i + 2] < 128 &&
          bufferArray[i + 3] < 128 &&
          bufferArray[i + 4] < 128 &&
          bufferArray[i + 5] < 128 &&
          bufferArray[i + 6] < 999 &&
          bufferArray[i + 7] < 999) {
        int heart = bufferArray[i];
        double pi = _calculatePi(heart, bufferArray[i + 2]);
        int si = _getSi(pi);
        int wave = bufferArray[i + 1];
        int pr = bufferArray[i + 2] >= 64 ? bufferArray[i + 3] + 128 : bufferArray[i + 3];
        int spo2 = bufferArray[i + 4];
        int battery = bufferArray[i + 5];
        int af = _calculateAF(bufferArray[i + 6], bufferArray[i + 7]);

        readData(spo2, pr, pi, si, heart, wave, 0, af, battery);

        i += 8;
        validIndex = i;
        continue;
      }
      i += 1;
      validIndex = i;
    }
    bufferArray = bufferArray.sublist(validIndex);
  }

  void _analysisBciRrAf(List<int> array) {
    bufferArray += array;
    var i = 0;
    var validIndex = 0;
    var maxCount = bufferArray.length - 9;
    while (i <= maxCount) {
      if (bufferArray[i] >= 128 &&
          bufferArray[i + 1] < 128 &&
          bufferArray[i + 2] < 128 &&
          bufferArray[i + 3] < 128 &&
          bufferArray[i + 4] < 128 &&
          bufferArray[i + 5] < 128 &&
          bufferArray[i + 6] < 999 &&
          bufferArray[i + 7] < 999 &&
          bufferArray[i + 8] < 128) {
        int heart = bufferArray[i];
        double pi = _calculatePi(heart, bufferArray[i + 2]);
        int si = _getSi(pi);
        int wave = bufferArray[i + 1];
        int pr = bufferArray[i + 2] >= 64 ? bufferArray[i + 3] + 128 : bufferArray[i + 3];
        int spo2 = bufferArray[i + 4];
        int battery = bufferArray[i + 5];
        int af = _calculateAF(bufferArray[i + 6], bufferArray[i + 7]);
        int rr = bufferArray[i + 8];

        readData(spo2, pr, pi, si, heart, wave, rr, af, battery);

        i += 9;
        validIndex = i;
        continue;
      }
      i += 1;
      validIndex = i;
    }
    bufferArray = bufferArray.sublist(validIndex);
  }

  void _animalBciBm1000AI(List<int> array){
    bufferArray += array;
    var i = 0;
    var validIndex = 0;
    var maxCount = bufferArray.length - 7;
    while (i <= maxCount) {
      if (bufferArray[i] >= 128 &&
          bufferArray[i + 1] < 128 &&
          bufferArray[i + 2] < 128 &&
          bufferArray[i + 3] < 128 &&
          bufferArray[i + 4] < 128 &&
          bufferArray[i + 5] < 128 &&
          bufferArray[i + 6] < 128) {
        int heart = bufferArray[i];
        double pi = _calculatePi(heart, bufferArray[i + 2]);
        int si = _getSi(pi);
        int wave = bufferArray[i + 1];
        int pr = _calculatePr(bufferArray[i + 2], bufferArray[i + 3], bufferArray[i + 6]);
        int spo2 = bufferArray[i + 4];
        int battery = bufferArray[i + 5];

        readData(spo2, pr, pi, si, heart, wave, 0, 0, battery);

        i += 7;
        validIndex = i;
        continue;
      }
      i += 1;
      validIndex = i;
    }
    bufferArray = bufferArray.sublist(validIndex);
  }

  //Calculate PI
  double _calculatePi(int lower, int higher) => (((lower & 0X0F) + (higher & 0x0F) * 16) / 10.0).toDou1;

  //Calculating PR (BM1000A-I)
  int _calculatePr(int one, int two, int three) {
    int pr = ((one & 0x40) << 7) | (two & 0x7F) | ((three & 0x01) << 8);
    return pr >= 250 ? 250 : (pr <= 0 ? 0 : pr);
  }

  //Calculation of AF (atrial fibrillation)
  int _calculateAF(int sixBits, int sevenBits) {
    int af = ((sixBits & 0x7F) + ((sevenBits & 0x3F) * 128)).toInt();
    return af >= 999 ? 999 : (af <= 0 ? 0 : af);
  }

  /*
   * spo2: Blood oxygen
   * pr: Pulse rate
   * si: Signal index
   * heart: Pulse sounds(buzzer)
   * wave: Volumetric waves(Pulse wave)
   * rr: Respiratory rate
   * af: Atrial fibrillation
   * battery: Battery level
   */
  void readData(int spo2, int pr, double pi, int si, int heart, int wave, int rr, int af, int battery) {
    if (spo2 < 35 || spo2 > 100) spo2 = 0;
    if (pr < 25 || pr > 250) pr = 0;
    //Reset PI and SI based on blood oxygen pulse rate
    if (spo2 <= 0 && pr <= 0) {
      pi = 0.0;
      si = 0;
    }
    this.spo2 = spo2;
    this.pr = pr;
    this.pi = pi;
    this.si = si;
    this.rr = rr;
    this.af = af;
    this.battery = battery;
  }
}

extension Format on num {
  String get intVal => this > 0 ? '$this' : '--';
  String get asFixed => this > 0 ? toStringAsFixed(1) : '--';
  double get toDou1 => this > 0 ? double.parse(toStringAsFixed(1)) :  0.0;
  String get batt => this > 0 ? '$this%' : '--';
}
