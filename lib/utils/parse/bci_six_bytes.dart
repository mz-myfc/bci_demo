import '../helper.dart';

/*
 * @description BCI: Package Length: 6 bytes - BATTERY
 * @author zl
 * @date 2024/9/6 15:35
 */
class BciSixBytes {
  static final BciSixBytes instance = BciSixBytes();

  List<int> _buffArray = [];

  void init() {
    _buffArray = [];
  }

  void parse(List<int> array) {
    _buffArray += array;

    var i = 0; //Current Index
    var validIndex = 0; //Valid Index
    var maxCount = _buffArray.length - 6; //Data Space
    while (i <= maxCount) {
      //Check the start head
      if (_buffArray[i] >= 128 &&
          _buffArray[i + 1] < 128 &&
          _buffArray[i + 2] < 128 &&
          _buffArray[i + 3] < 128 &&
          _buffArray[i + 4] < 128 &&
          _buffArray[i + 5] < 128) {

        int heart = _buffArray[i];
        double pi = _cPi(heart, _buffArray[i + 2]);
        int si = _toSi(pi);
        int wave = _buffArray[i + 1];
        int pr = _buffArray[i + 2] >= 64 ? _buffArray[i + 3] + 128 : _buffArray[i + 3];
        int spo2 = _buffArray[i + 4];
        int battery = _buffArray[i + 5];

        // Read Data
        Helper.h.readParseData(spo2, pr, pi, si, heart, wave, 0, 0, battery);

        i += 6;
        validIndex = i;
        continue;
      }
      i += 1;
      validIndex = i;
    }
    _buffArray = _buffArray.sublist(validIndex); //Data before the deletion of a valid index
  }

  //Calculate PI
  double _cPi(int lower, int higher) => (((lower & 0x0f) + (higher & 0x0f) * 16) / 10.0).toDou;

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