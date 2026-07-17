import 'package:data_monitor/data_monitor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

// 與 MaterialApp 共用同一把 navigatorKey，MonitorGate 才能把監控頁疊在所有頁面上。
final _navigatorKey = GlobalKey<NavigatorState>();

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Monitor',
      navigatorKey: _navigatorKey,
      // 路由採集：掛上 observer 即可自動記錄 push/pop。
      navigatorObservers: [MonitorNavigatorObserver()],
      // 懸浮鈕：掛在 builder，三指連點三下切換顯示 / 隱藏。
      builder: (context, child) => MonitorGate(
        navigatorKey: _navigatorKey,
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // HTTP 採集：只要掛上 DioMonitor 這個 interceptor 即可。
  final dio = Dio()..interceptors.add(DioMonitor());

  // MQTT 採集：不依賴 mqtt_client，呼叫端餵字串即可（模擬 engo 的收 / 送）。
  final mqtt = MqttMonitor();

  // App 事件 / 狀態採集。
  final appEvent = AppEventMonitor();
  int counter = 0;

  // 模擬一筆 engo 裝置 DP 上報（節錄自實機 log）。
  static const _deviceId = '6be6b5a8631246fcaa2d5e8c3e787d77';
  static const _dpReport =
      '{"power":"on","temperature_sensor":29,"humidity_set":65,'
      '"co2_sensor":0,"filter_days":90,"fire_alarm":"off","bypass_on":"off"}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Monitor 範例')),
      body: ListView(
        children: [
          const _SectionTitle('HTTP（內建 Dio channel）'),
          ListTile(
            title: const Text('GET 成功'),
            onTap: () => dio.get('https://jsonplaceholder.typicode.com/todos/1'),
          ),
          ListTile(
            title: const Text('POST 帶 body'),
            onTap: () => dio.post(
              'https://jsonplaceholder.typicode.com/posts',
              data: {'title': 'hi', 'items': [1, 2, 3]},
            ),
          ),
          ListTile(
            title: const Text('404 錯誤'),
            onTap: () => dio.get('https://jsonplaceholder.typicode.com/nope'),
          ),
          const Divider(),
          const _SectionTitle('MQTT（MqttMonitor channel）'),
          ListTile(
            title: const Text('收到裝置 DP 上報（inbound ←）'),
            subtitle: const Text('JSON payload 自動美化'),
            onTap: () => mqtt.received(
              'device/$_deviceId/dp/read',
              _dpReport,
              qos: 1,
            ),
          ),
          ListTile(
            title: const Text('下發控制（outbound →）'),
            onTap: () => mqtt.published(
              'device/$_deviceId/dp/write',
              '{"power":"off"}',
              qos: 1,
            ),
          ),
          ListTile(
            title: const Text('MQTT 連線 / 斷線 / 錯誤'),
            onTap: () {
              mqtt.connected('mqtt.smtengo.com', port: 22095);
              mqtt.error('MQTT 連接逾時', topic: 'device/$_deviceId/dp/read');
            },
          ),
          const Divider(),
          const _SectionTitle('App 事件 / 狀態 / 路由（P3）'),
          ListTile(
            title: const Text('記一筆 App 事件（帶 data）'),
            onTap: () => appEvent.event(
              '使用者登入',
              detail: 'AuthService',
              data: {'userId': 'u_1024', 'method': 'oauth', 'vip': true},
            ),
          ),
          ListTile(
            title: const Text('記一筆狀態變化（from → to）'),
            onTap: () {
              final from = counter;
              counter += 1;
              appEvent.stateChanged('counterProvider', from: from, to: counter);
            },
          ),
          ListTile(
            title: const Text('開啟第二頁（路由 push/pop 自動記錄）'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              settings: const RouteSettings(name: '/second'),
              builder: (_) => const SecondPage(),
            )),
          ),
          const Divider(),
          const _SectionTitle('自訂來源（一行 log）'),
          ListTile(
            title: const Text('記一筆純文字事件'),
            // 純文字 log：通用 API，免寫 channel。
            onTap: () => Monitor.instance.log(
              category: 'EVENT',
              title: '使用者點了按鈕',
              subtitle: 'HomePage / demo-event',
            ),
          ),
          ListTile(
            title: const Text('記一筆錯誤'),
            onTap: () => Monitor.instance.log(
              category: 'EVENT',
              title: '解析失敗',
              status: MonitorStatus.error,
              tabs: [
                MonitorTab(name: '詳情', sections: [
                  TextSection('Error', 'FormatException: unexpected token',
                      color: Colors.red),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 第二頁：純粹用來示範路由 push/pop 會被 MonitorNavigatorObserver 記錄。
class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('第二頁')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回（會記一筆 ROUTE pop）'),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
