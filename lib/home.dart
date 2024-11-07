import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'utils/ble/ble_helper.dart';
import 'utils/ble/cmd.dart';
import 'utils/ble/permission.dart';
import 'utils/helper.dart';
import 'utils/notice.dart';
import 'utils/pop/pop.dart';

/*
 * @description HomePage
 * @author zl
 * @date 2023/11/20 16:13
 */
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _protocolItem = 'BCI';
  String _frequencyItem = '100Hz';

  @override
  void initState() {
    WakelockPlus.enable();
    Helper.h.startTimer();
    Future.delayed(
      const Duration(seconds: 1), () async => await Ble.helper.bleState(),
    );
    super.initState();
  }

  //Switch Protocol
  void _onProtocolChange(String? v) {
    _protocolItem = v ?? 'BCI';
    Cmd.instance.switchProtocol(_protocolItem);
    setState(() {});
  }

  //Applies To Berry Protocol
  void _onFrequencyChange(String? v) {
    _frequencyItem = v ?? '100Hz';
    Cmd.instance.switchFrequency(_frequencyItem);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            DropdownButton<String>(
              alignment: Alignment.centerRight,
              value: _protocolItem,
              onChanged: _onProtocolChange,
              borderRadius: const BorderRadius.all(Radius.circular(10.0)),
              items: ['BCI', 'BERRY'].map((v) {
                return DropdownMenuItem<String>(value: v, child: Text(v));
              }).toList(),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              alignment: Alignment.centerRight,
              value: _frequencyItem,
              onChanged: _onFrequencyChange,
              borderRadius: const BorderRadius.all(Radius.circular(10.0)),
              items: ['1Hz', '50Hz', '100Hz', '200Hz', 'Stop'].map((v) {
                return DropdownMenuItem<String>(
                  value: v,
                  child: Text(v),
                );
              }).toList(),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.bluetooth),
              onPressed: () => PermissionHelper.helper.scanBluetooth(),
            ),
          ],
        ),
        body: ChangeNotifierProvider(
          data: Helper.h,
          child: Consumer<Helper>(
            builder: (context, helper) => SingleChildScrollView(
              padding: const EdgeInsets.all(5),
              child: Column(
                children: [
                  HeadView(title: 'Name', value: helper.deviceName),
                  HeadView(title: 'ID', value: helper.deviceId),
                  HeadView(title: 'Battery', value: helper.battery.battery),
                  HeadView(title: 'Model', value: helper.model),
                  HeadView(title: 'PacketFreq', value: helper.packetFreq),
                  HeadView(
                    title: 'Software Version',
                    value: helper.sv,
                    border: true,
                    onTap: () => Ble.helper.write([0xFF]),
                  ),
                  HeadView(
                    title: 'Hardware Version',
                    value: helper.hv,
                    border: true,
                    onTap: () => Ble.helper.write([0xFE]),
                  ),
                  Divider(color: Colors.purple.shade100),
                  Flex(
                    direction: Axis.horizontal,
                    children: [
                      MyBox(title: 'SpO₂', value: helper.spo2.intVal, unit: '%'),
                      MyBox(title: 'PR', value: helper.pr.intVal, unit: 'bpm'),
                    ],
                  ),
                  Flex(
                    direction: Axis.horizontal,
                    children: [
                      MyBox(title: 'RR', value: helper.rr.intVal, unit: 'bpm'),
                      MyBox(title: 'AF', value: helper.af.intVal, unit: ''),
                    ],
                  ),
                  Flex(
                    direction: Axis.horizontal,
                    children: [
                      MyBox(title: 'PI', value: helper.pi.asFixed, unit: ''),
                      MyBox(title: 'SI', value: helper.si.intVal, unit: ''),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.only(top: 15),
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.warning_outlined, color: Colors.amber),
                      onPressed: () => Pop.helper.promptPop(),
                    ),
                  ),
                  const Text('v1.0', style: TextStyle(fontSize: 15)),
                  const Text('Shanghai Berry Electronic Tech Co., Ltd.', style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    WakelockPlus.disable();
    Helper.h.stopTimer();
    super.dispose();
  }
}

class MyBox extends StatelessWidget {
  const MyBox({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
  });

  final String title;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 90,
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(width: 0.5, color: Colors.grey),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 5,
                left: 5,
                child: Text(title, style: const TextStyle(fontSize: 15)),
              ),
              Text(value, style: const TextStyle(fontSize: 25)),
              Positioned(
                right: 5,
                bottom: 5,
                child: Text(unit ?? '', style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      );
}

class HeadView extends StatelessWidget {
  const HeadView({
    super.key,
    required this.title,
    required this.value,
    this.border = false,
    this.onTap,
  });

  final String title;
  final String value;
  final bool border;
  final Function()? onTap;

  @override
  Widget build(BuildContext context) => Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          children: [
            border
                ? InkWell(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        border: Border.all(width: 1, color: Colors.grey),
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      child: Text(
                        '$title:',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  )
                : Text('$title:', style: const TextStyle(fontSize: 15)),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}
