library flutter_barcode_listener;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

class BarcodeKeyboardListener extends StatefulWidget {
  final Widget child;
  final BarcodeScannedCallback _onBarcodeScanned;
  final Duration _bufferDuration;
  final bool useKeyDownEvent;
  final bool caseSensitive;

  BarcodeKeyboardListener({
    Key? key,
    required this.child,
    required Function(String) onBarcodeScanned,
    this.useKeyDownEvent = false,
    Duration bufferDuration = hundredMs,
    this.caseSensitive = false,
  })  : _onBarcodeScanned = onBarcodeScanned,
        _bufferDuration = bufferDuration,
        super(key: key);

  @override
  _BarcodeKeyboardListenerState createState() => _BarcodeKeyboardListenerState(
      _onBarcodeScanned, _bufferDuration, useKeyDownEvent, caseSensitive);
}

const Duration aSecond = Duration(seconds: 1);
const Duration hundredMs = Duration(milliseconds: 100);
const String lineFeed = '\n';

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
  List<String> _scannedChars = [];
  DateTime? _lastScannedCharCodeTime;
  late StreamSubscription<String?> _keyboardSubscription;

  final BarcodeScannedCallback _onBarcodeScannedCallback;
  final Duration _bufferDuration;
  final _controller = StreamController<String?>();
  final bool _useKeyDownEvent;
  final bool _caseSensitive;
  bool _isShiftPressed = false;

  _BarcodeKeyboardListenerState(this._onBarcodeScannedCallback,
      this._bufferDuration, this._useKeyDownEvent, this._caseSensitive) {
    HardwareKeyboard.instance.addListener(_keyBoardCallback);
    _keyboardSubscription =
        _controller.stream.where((char) => char != null).listen(onKeyEvent);
  }

  void onKeyEvent(String? char) {
    checkPendingCharCodesToClear();
    _lastScannedCharCodeTime = DateTime.now();
    if (char == lineFeed) {
      String scannedCode = _scannedChars.join();
      print("Scanned barcode: $scannedCode");
      _onBarcodeScannedCallback.call(scannedCode);
      resetScannedCharCodes();
    } else {
      if (char != null && RegExp(r'^[a-zA-Z0-9]$').hasMatch(char)) {
        _scannedChars.add(char);
      }
    }
  }

  void checkPendingCharCodesToClear() {
    if (_lastScannedCharCodeTime != null) {
      if (_lastScannedCharCodeTime!
          .isBefore(DateTime.now().subtract(_bufferDuration))) {
        resetScannedCharCodes();
      }
    }
  }

  void resetScannedCharCodes() {
    _lastScannedCharCodeTime = null;
    _scannedChars = [];
  }

  void _keyBoardCallback(KeyboardEvent keyEvent) {
    print("Key event: ${keyEvent.character}, Physical key: ${keyEvent.physicalKey}");

    if (keyEvent.physicalKey.usbHidUsage > 255 &&
        keyEvent.physicalKey != PhysicalKeyboardKey.enter &&
        keyEvent.physicalKey != PhysicalKeyboardKey.shiftLeft) return;
    if ((!_useKeyDownEvent && keyEvent is KeyUpEvent) ||
        (_useKeyDownEvent && keyEvent is KeyDownEvent)) {
      if (keyEvent is KeyDownEvent) {
        if (keyEvent.physicalKey == PhysicalKeyboardKey.shiftLeft) {
          _isShiftPressed = true;
        } else {
          if (_isShiftPressed && _caseSensitive) {
            _isShiftPressed = false;
            _controller.sink.add(keyEvent.character?.toUpperCase());
          } else {
            _controller.sink.add(keyEvent.character);
          }
        }
      }
      if (keyEvent.physicalKey == PhysicalKeyboardKey.enter) {
        _controller.sink.add(lineFeed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _keyboardSubscription.cancel();
    _controller.close();
    HardwareKeyboard.instance.removeListener(_keyBoardCallback);
    super.dispose();
  }
}
