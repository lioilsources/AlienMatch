import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory WebSocket: tests push server events with [push].
class FakeSocket with StreamChannelMixin<dynamic> implements WebSocketChannel {
  final _in = StreamController<dynamic>();
  final _out = StreamController<dynamic>();
  Uri? uri;

  void push(String event) => _in.add(event);

  @override
  Stream<dynamic> get stream => _in.stream;

  @override
  WebSocketSink get sink => _Sink(_out);

  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  Future<void> get ready => Future.value();
}

class _Sink implements WebSocketSink {
  _Sink(this._c);
  final StreamController<dynamic> _c;
  @override
  void add(dynamic data) => _c.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
  @override
  Future<void> get done => Future.value();
}
