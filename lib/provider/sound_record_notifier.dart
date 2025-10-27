import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:social_media_recorder/audio_encoder_type.dart';
// import 'package:uuid/uuid.dart';

class SoundRecordNotifier extends ChangeNotifier {
  int _counter = 0;
  int _localCounterForMaxRecordTime = 0;
  GlobalKey key = GlobalKey();
  int? maxRecordTime;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;

    // Cancel all timers to prevent callbacks after disposal
    try {
      _timer?.cancel();
      _timerCounter?.cancel();
    } catch (e) {
      print('Error cancelling timers in dispose: $e');
    }

    // Stop recording if active
    try {
      recordMp3.stop();
    } catch (e) {
      print('Error stopping recording in dispose: $e');
    }

    super.dispose();
  }

  void safeNotify() {
    if (!_isDisposed) {
      try {
        notifyListeners();
      } catch (e) {
        // Handle potential notification errors gracefully
        print('Error in notifyListeners: $e');
      }
    }
  }

  /// Immediate notification for critical UI updates (like user interactions)
  void immediateNotify() {
    if (!_isDisposed) {
      try {
        notifyListeners();
      } catch (e) {
        print('Error in immediateNotify: $e');
      }
    }
  }

  /// This Timer Just For wait about 1 second until starting record
  Timer? _timer;

  /// This time for counter wait about 1 send to increase counter
  Timer? _timerCounter;

  /// Use last to check where the last draggable in X
  double last = 0;

  /// Used when user enter the needed path
  String initialStorePathRecord = "";

  /// recording mp3 sound Object
  AudioRecorder recordMp3 = AudioRecorder();

  /// recording mp3 sound to check if all permisiion passed
  bool _isAcceptedPermission = false;

  /// used to update state when user draggable to the top state
  double currentButtonHeihtPlace = 0;

  /// used to know if isLocked recording make the object true
  /// else make the object isLocked false
  bool isLocked = false;

  /// when pressed in the recording mic button convert change state to true
  /// else still false
  bool isShow = false;

  /// to show second of recording
  late int second;

  /// to show minute of recording
  late int minute;

  /// to know if pressed the button
  late bool buttonPressed;

  /// used to update space when dragg the button to left
  late double edge;
  late bool loopActive;

  /// store final path where user need store mp3 record
  late bool startRecord;

  /// store the value we draggble to the top
  late double heightPosition;

  /// store status of record if lock change to true else
  /// false
  late bool lockScreenRecord;
  late String mPath;

  /// function called when start recording
  Function()? startRecording;
  Function(File soundFile, String time) sendRequestFunction;

  /// function called when stop recording, return the recording time (even if time < 1)
  Function(String time)? stopRecording;

  late AudioEncoderType encode;

  // ignore: sort_constructors_first

  SoundRecordNotifier({
    required this.stopRecording,
    required this.sendRequestFunction,
    required this.startRecording,
    this.edge = 0.0,
    this.minute = 0,
    this.second = 0,
    this.buttonPressed = false,
    this.loopActive = false,
    this.mPath = '',
    this.startRecord = false,
    this.heightPosition = 0,
    this.lockScreenRecord = false,
    this.encode = AudioEncoderType.AAC,
    this.maxRecordTime,
  }) {
    // Initialize permissions but don't start recording automatically
    voidInitialSound();
  }

  /// To increase counter after 1 sencond
  void _mapCounterGenerater() {
    _timerCounter = Timer(const Duration(seconds: 1), () {
      _increaseCounterWhilePressed();
      if (buttonPressed) _mapCounterGenerater();
    });
  }

  finishRecording() async {
    if (buttonPressed) {
      String _time = minute.toString() + ":" + second.toString();
      try {
        if (second > 0 || minute > 0) {
          String path = mPath;
          sendRequestFunction(File.fromUri(Uri(path: path)), _time);
        }
      } catch (e) {
        // Handle any errors during file processing
        print('Error processing recording: $e');
      } finally {
        // Always call stopRecording callback regardless of duration or success
        if (stopRecording != null) {
          stopRecording!(_time);
        }
      }
    }
    await resetEdgePadding();
  }

  /// used to reset all value to initial value when end the record
  resetEdgePadding() async {
    try {
      if (_initWidth == -33) {
        RenderBox box = key.currentContext?.findRenderObject() as RenderBox;
        Offset position = box.localToGlobal(Offset.zero);
        _initWidth = position.dx;
      }
    } catch (e) {
      // Handle render box context errors gracefully
      print('Error getting render box position: $e');
    }

    // Reset all state variables - these should always be reset regardless of errors
    _localCounterForMaxRecordTime = 0;
    isLocked = false;
    edge = 0;
    buttonPressed = false;
    second = 0;
    minute = 0;
    isShow = false;
    key = GlobalKey();
    heightPosition = 0;
    lockScreenRecord = false;

    // Cancel timers safely
    try {
      if (_timer != null) _timer!.cancel();
      if (_timerCounter != null) _timerCounter!.cancel();
    } catch (e) {
      print('Error cancelling timers: $e');
    }

    // Stop recording safely
    try {
      final value = await recordMp3.isRecording();
      if (value == true) {
        await recordMp3.stop();
        recordMp3 = AudioRecorder();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      // Create new recorder instance even if stop failed
      recordMp3 = AudioRecorder();
    } finally {
      safeNotify();
    }
  }

  String _getSoundExtention() {
    if (encode == AudioEncoderType.AAC ||
        encode == AudioEncoderType.AAC_LD ||
        encode == AudioEncoderType.AAC_HE ||
        encode == AudioEncoderType.OPUS) {
      return ".m4a";
    } else {
      return ".3gp";
    }
  }

  /// used to get the current store path
  Future<String> getFilePath() async {
    String _sdPath = "";
    Directory tempDir = await getTemporaryDirectory();
    _sdPath =
        initialStorePathRecord.isEmpty ? tempDir.path : initialStorePathRecord;
    var d = Directory(_sdPath);
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    DateTime now = DateTime.now();
    String convertedDateTime =
        "${_counter.toString()}${now.year.toString()}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    // print("the current data is $convertedDateTime");
    _counter++;
    String storagePath =
        _sdPath + "/" + convertedDateTime + _getSoundExtention();
    mPath = storagePath;
    return storagePath;
  }

  /// used to change the draggable to top value
  setNewInitialDraggableHeight(double newValue) {
    currentButtonHeihtPlace = newValue;
  }

  double _initWidth = -33;

  /// used to change the draggable to top value
  /// or To The X vertical
  /// and update this value in screen
  updateScrollValue(Offset currentValue, BuildContext context) async {
    if (buttonPressed == true) {
      final x = currentValue;

      /// take the diffrent between the origin and the current
      /// draggable to the top place
      double hightValue = currentButtonHeihtPlace - x.dy;

      /// if reached to the max draggable value in the top
      if (hightValue >= 50) {
        isLocked = true;
        lockScreenRecord = true;
        hightValue = 50;
        immediateNotify(); // Critical UI state change
      }
      if (hightValue < 0) hightValue = 0;
      heightPosition = hightValue;
      lockScreenRecord = isLocked;
      immediateNotify(); // Critical UI update during drag

      /// this operation for update X oriantation
      /// draggable to the left or right place
      try {
        RenderBox box = key.currentContext?.findRenderObject() as RenderBox;
        Offset position = box.localToGlobal(Offset.zero);
        if (position.dx <= MediaQuery.of(context).size.width * 0.6) {
          String _time = minute.toString() + ":" + second.toString();
          try {
            if (stopRecording != null) stopRecording!(_time);
          } catch (e) {
            print('Error in stopRecording callback: $e');
          } finally {
            resetEdgePadding();
          }
        } else if (x.dx >= MediaQuery.of(context).size.width) {
          edge = 0;
          edge = 0;
        } else {
          edge = (_initWidth - x.dx) > 0 ? (_initWidth - x.dx) : 0;

          // if (x.dx <= MediaQuery.of(context).size.width * 0.5) {}
          // if (last < x.dx) {
          //   edge = edge -= x.dx / 200;
          //   if (edge < 0) {
          //     edge = 0;
          //   }
          // } else if (last > x.dx) {
          //   edge = edge += x.dx / 200;
          // }
          // last = x.dx;
        }
        // ignore: empty_catches
      } catch (e) {}
      immediateNotify(); // Critical UI update during drag
    }
  }

  /// this function to manage counter value
  /// when reached to 60 sec
  /// reset the sec and increase the min by 1
  _increaseCounterWhilePressed() async {
    if (loopActive) {
      return;
    }

    loopActive = true;
    if (maxRecordTime != null) {
      if (_localCounterForMaxRecordTime >= maxRecordTime!) {
        loopActive = false;
        finishRecording();
      }
      _localCounterForMaxRecordTime++;
    }
    second = second + 1;
    buttonPressed = buttonPressed;
    if (second == 60) {
      second = 0;
      minute = minute + 1;
    }

    safeNotify();
    loopActive = false;
    safeNotify();
  }

  /// this function to start record voice
  record(Function()? startRecord) async {
    if (!_isAcceptedPermission) {
      try {
        // Request all permissions at once to avoid concurrent requests
        Map<Permission, PermissionStatus> statuses =
            await [
              Permission.microphone,
              Permission.manageExternalStorage,
              Permission.storage,
            ].request();

        // Check if all required permissions are granted
        bool allGranted =
            statuses[Permission.microphone]?.isGranted == true &&
            (statuses[Permission.storage]?.isGranted == true ||
                statuses[Permission.manageExternalStorage]?.isGranted == true);

        if (allGranted) {
          _isAcceptedPermission = true;
        } else {
          // Handle permission denial
          print('Required permissions not granted');
          return;
        }
      } catch (e) {
        print('Error requesting permissions: $e');
        return;
      }
    }

    // Only proceed if permissions are granted
    if (_isAcceptedPermission) {
      buttonPressed = true;
      String recordFilePath = await getFilePath();
      if (_timer != null) {
        _timer?.cancel();
      }
      _timer = Timer(const Duration(milliseconds: 400), () {
        recordMp3.start(const RecordConfig(), path: recordFilePath);
      });

      if (startRecord != null) {
        startRecord();
      }

      _mapCounterGenerater();
      immediateNotify(); // Critical UI update when recording starts
    }
    safeNotify();
  }

  /// to check permission
  voidInitialSound() async {
    // if (Platform.isIOS) _isAcceptedPermission = true;

    startRecord = false;

    try {
      // Check current permission statuses first
      final micStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;

      // If microphone and at least one storage permission is granted, we're good
      if (micStatus.isGranted &&
          (storageStatus.isGranted || manageStorageStatus.isGranted)) {
        _isAcceptedPermission = true;
      } else {
        // Only request permissions that aren't already granted
        List<Permission> permissionsToRequest = [];

        if (!micStatus.isGranted) {
          permissionsToRequest.add(Permission.microphone);
        }

        if (!storageStatus.isGranted && !manageStorageStatus.isGranted) {
          permissionsToRequest.add(Permission.storage);
          permissionsToRequest.add(Permission.manageExternalStorage);
        }

        if (permissionsToRequest.isNotEmpty) {
          final results = await permissionsToRequest.request();

          // Check if we have the minimum required permissions
          bool micGranted =
              results[Permission.microphone]?.isGranted == true ||
              micStatus.isGranted;
          bool storageGranted =
              results[Permission.storage]?.isGranted == true ||
              results[Permission.manageExternalStorage]?.isGranted == true ||
              storageStatus.isGranted ||
              manageStorageStatus.isGranted;

          _isAcceptedPermission = micGranted && storageGranted;
        }
      }
    } catch (e) {
      print('Error checking/requesting permissions in voidInitialSound: $e');
      _isAcceptedPermission = false;
    }
  }
}
