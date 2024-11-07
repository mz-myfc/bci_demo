import '../../helper.dart';

/*
 * @description Berry Protocol
 * @author zl
 * @date 2024/9/9 13:34
 */
class BerryProtocol {
  static final BerryProtocol instance = BerryProtocol();

  List<int> _buffArray = [];

  void init() {
    _buffArray = [];
  }

  void parse(List<int> array) {
    _buffArray += array;
    
    var i = 0; //Current Index
    var validIndex = 0; //Valid Index
    var maxIndex = _buffArray.length - 20; //Data Space
    while (i <= maxIndex) {
      //Failed to match the headers
      if (_buffArray[i] != 0xFF || _buffArray[i + 1] != 0xAA) {
        i += 1;
        validIndex = i;
        continue;
      }
      //The header is successfully matched
      var total = 0;
      var checkSum = _buffArray[i + 19];
      for (var index = 0; index <= 18; index++) {
        total += _buffArray[i + index];
      }
      //If the verification fails, discard the two data
      if (checkSum != total % 256) {
        i += 2;
        validIndex = i;
        continue;
      }
      var data = _buffArray.sublist(i, i + 19);

      if (data.length >= 19) {
        var pi = data[10] / 10.0;
        var heartBeep = data[4] & 0x08; //0-No Beep, 1-Beep
        Helper.h.packetFreq = '${data[18]}Hz';
        Helper.h.readParseData(data[4], data[6], pi, _toSi(pi), heartBeep, data[12], 0, 0, data[17]);
      }

      i += 20; //Move back one group
      validIndex = i;
      continue;
    }
    _buffArray = _buffArray.sublist(validIndex); //Data before the deletion of a valid index
  }

  //SI
  int _toSi(double pi) {
    if (pi >= 20.0) {
      return 8;
    } else if (pi >= 10.3) {
      return 7;
    } else if (pi >= 5.3) {
      return 6;
    } else if (pi >= 2.7) {
      return 5;
    } else if (pi >= 1.4) {
      return 4;
    } else if (pi >= 0.7) {
      return 3;
    } else if (pi >= 0.4) {
      return 2;
    } else if (pi >= 0.2) {
      return 1;
    } else {
      return 0;
    }
  }
}
