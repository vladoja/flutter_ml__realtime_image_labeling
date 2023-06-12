import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

void main() => runApp(MaterialApp(home: _MyHomePage()));

class _MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<_MyHomePage> {
  dynamic _scanResults;
  CameraDescription? _currentCamera;
  CameraController? _cameraController;
  String result = "results to be shown here";
  dynamic imageLabeler;

  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    final ImageLabelerOptions options =
        ImageLabelerOptions(confidenceThreshold: 0.5);
    imageLabeler = ImageLabeler(options: options);
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController!.dispose();
    super.dispose();
  }

  Future<CameraDescription> _getCamera(CameraLensDirection dir) async {
    return await availableCameras().then(
      (List<CameraDescription> cameras) => cameras.firstWhere(
        (CameraDescription camera) => camera.lensDirection == dir,
      ),
    );
  }

  _initializeCamera() async {
    _currentCamera = await _getCamera(_direction);
    // TODO: NULL check
    _cameraController = CameraController(
      _currentCamera!,
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // for Android
          : ImageFormatGroup.bgra8888, //
    );
    await _cameraController!.initialize();
    setState(() {
      _cameraController;
    });
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;
      try {
        // await doSomethingWith(image)
        await doImageLabeling(image);
      } catch (e) {
        print('Image labeling failed: $e');
        // await handleExepction(e)
      } finally {
        _isDetecting = false;
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // get camera rotation
    final cameraOrientations = _currentCamera!.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(cameraOrientations);
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  Future<void> doImageLabeling(CameraImage image) async {
    print("Running doImageLabeling()");
    result = "";
    InputImage inputImage = _inputImageFromCameraImage(image)!;

    assert((inputImage != null), "InpuImage can't null");

    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);

    result = "";
    print("New Labels: " + labels.length.toStringAsPrecision(2));
    for (ImageLabel label in labels) {
      final String text = label.label;
      final int index = label.index;
      final double confidence = label.confidence;
      result += "$text    ${confidence.toStringAsFixed(2)}\n";
    }
    // Ready for next image
    setState(() {
      result;
    });
    // await Future.delayed(Duration(seconds: 1));
    await Future.delayed(const Duration(milliseconds: 500));
    // isBusy = false;
    _isDetecting = false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Stack(
        fit: StackFit.expand,
        children: [
          (_cameraController == null || !_cameraController!.value.isInitialized)
              ? const Center(
                  child: Text('Waiting For Camera'),
                )
              : CameraPreview(_cameraController!),
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 10),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                result,
                style: const TextStyle(color: Colors.white, fontSize: 25),
              ),
            ),
          )
        ],
      ),
    );
  }
}
