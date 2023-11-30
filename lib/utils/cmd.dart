// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class Cmd {
  static Uuid SERVICE_UUID                = Uuid.parse("49535343-FE7D-4AE5-8FA9-9FAFD205E455"); //service uuid
  static Uuid CHARACTERISTIC_UUID_SEND    = Uuid.parse("49535343-1E4D-4BD9-BA61-23C647249616"); //device send to phone
  static Uuid CHARACTERISTIC_UUID_RECEIVE = Uuid.parse("49535343-8841-43F4-A8D4-ECBE34729BB3"); //phone write to device
  static Uuid CHARACTERISTIC_UUID_RENAME  = Uuid.parse("00005343-0000-1000-8000-00805F9B34FB"); //rename device
  static Uuid CHARACTERISTIC_UUID_MAC     = Uuid.parse("00005344-0000-1000-8000-00805F9B34FB"); //read mac address

  static const String BCI          = '00:00:00'; //BCI: Package Length: 5 bytes
  static const String BCI_BATTERY  = '00:01:00'; //BCI: Package Length: 6 bytes - BATTERY
  static const String BCI_RR       = '00:02:00'; //BCI: Package Length: 7 bytes - RR
  static const String BCI_AF       = '00:03:00'; //BCI: Package Length: 5 bytes - AF
  static const String BCI_RR_AF    = '00:04:00'; //BCI: Package Length: 9 bytes - RR + AF
  static const String BCI_BM100A_I = '00:05:00'; //BCI: Package Length: 7 bytes - BM1000A-I
}