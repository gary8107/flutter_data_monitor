import 'package:dio/dio.dart' as dio;
import 'package:flutter/painting.dart' show Color;

import '../monitor_entry.dart';
import '../monitor_log.dart';
import '../monitor_section.dart';

/// 把 Dio 的請求 / 回應 / 錯誤採集成 [MonitorEntry]。
///
/// 這是「採集層」的參考範例：它只做一件事——把來源資料轉成通用條目丟進
/// [MonitorLog]。你要接新來源（MQTT、事件匯流排…）時照這個模式寫即可。
///
/// 用法：
/// ```dart
/// final dioClient = Dio()..interceptors.add(DioMonitor());
/// ```
class DioMonitor extends dio.Interceptor {
  DioMonitor({MonitorLog? log}) : log = log ?? Monitor.instance;

  /// 目標記錄流，預設全域單例。
  final MonitorLog log;

  /// 暫存進行中的請求，收到回應時用它找回同一筆條目做更新。
  final _pending = <dio.RequestOptions, MonitorEntry>{};

  static const String category = 'HTTP';

  @override
  void onRequest(
    dio.RequestOptions options,
    dio.RequestInterceptorHandler handler,
  ) {
    final entry = MonitorEntry(
      category: category,
      title: '${options.method}  ${options.uri.path}',
      subtitle: options.uri.toString(),
      status: MonitorStatus.pending,
      tabs: [_requestTab(options)],
      raw: options,
    );
    _pending[options] = entry;
    log.add(entry);
    handler.next(options);
  }

  @override
  void onResponse(
    dio.Response response,
    dio.ResponseInterceptorHandler handler,
  ) {
    final status = (response.statusCode ?? 0) >= 400
        ? MonitorStatus.error
        : MonitorStatus.success;
    _complete(
      response.requestOptions,
      status: status,
      responseTab: _responseTab(response),
      statusLabel: response.statusCode?.toString(),
    );
    handler.next(response);
  }

  @override
  void onError(dio.DioException err, dio.ErrorInterceptorHandler handler) {
    _complete(
      err.requestOptions,
      status: MonitorStatus.error,
      responseTab: _responseTab(err.response, error: err),
      statusLabel: err.response?.statusCode?.toString() ?? 'ERR',
    );
    handler.next(err);
  }

  /// 收尾：找回進行中的條目就地更新；若找不到（少見）則補一筆完整的。
  void _complete(
    dio.RequestOptions options, {
    required MonitorStatus status,
    required MonitorTab responseTab,
    String? statusLabel,
  }) {
    final title =
        '${options.method}  ${options.uri.path}${statusLabel == null ? '' : '  ($statusLabel)'}';
    final entry = _pending.remove(options);
    if (entry == null) {
      log.add(MonitorEntry(
        category: category,
        title: title,
        subtitle: options.uri.toString(),
        status: status,
        tabs: [_requestTab(options), responseTab],
        raw: options,
      ));
      return;
    }
    entry
      ..title = title
      ..status = status
      ..tabs = [...entry.tabs, responseTab];
    log.update(entry);
  }

  MonitorTab _requestTab(dio.RequestOptions options) => MonitorTab(
        name: 'Request',
        sections: [
          KeyValueSection.fromMap('URL', {
            'method': options.method,
            'uri': options.uri.toString(),
          }),
          KeyValueSection(
            'Headers',
            options.headers.entries
                .map((e) => MapEntry(e.key, '${e.value}'))
                .toList(),
          ),
          BodySection('Body', options.data),
        ],
      );

  MonitorTab _responseTab(dio.Response? response, {dio.DioException? error}) =>
      MonitorTab(
        name: 'Response',
        sections: [
          KeyValueSection.fromMap('Result', {
            'status': response?.statusCode?.toString() ?? '-',
            'message': response?.statusMessage ?? '',
          }),
          KeyValueSection(
            'Headers',
            response == null
                ? const []
                : response.headers.map.entries
                    .map((e) => MapEntry(e.key, e.value.join(', ')))
                    .toList(),
          ),
          if (error != null)
            TextSection('Error', error.toString(),
                color: const Color(0xFFD32F2F)),
          BodySection('Body', response?.data),
        ],
      );
}
