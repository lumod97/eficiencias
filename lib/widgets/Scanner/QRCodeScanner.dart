import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class ContinuousQRScanner extends StatefulWidget {
  @override
  _ContinuousQRScannerState createState() => _ContinuousQRScannerState();
}

class _ContinuousQRScannerState extends State<ContinuousQRScanner> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  final BarcodeScanner _barcodeScanner = GoogleMlKit.vision.barcodeScanner();
  CameraLensDirection _direction = CameraLensDirection.back;
  String _qrCodes = ""; // String to store detected QR codes

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere((camera) => camera.lensDirection == _direction);

    _cameraController = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    await _cameraController?.initialize();

    _cameraController?.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      try {
        final inputImage = _getInputImageFromCameraImage(image);
        _barcodeScanner.processImage(inputImage).then((barcodes) {
          if (barcodes.isNotEmpty) {
            setState(() {
              _qrCodes = barcodes.map((barcode) => barcode.rawValue ?? '').join('\n');
            });
          }
          _isDetecting = false;
        }).catchError((e) {
          print('Error al procesar la imagen: $e');
          _isDetecting = false;
        });
      } catch (e) {
        print('Error al convertir la imagen: $e');
        _isDetecting = false;
      }
    });

    setState(() {});
  }

  InputImage _getInputImageFromCameraImage(CameraImage image) {
    final allBytes = Uint8List.fromList(
      image.planes.fold<List<int>>([], (buffer, plane) => buffer..addAll(plane.bytes)),
    );

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    const InputImageRotation imageRotation = InputImageRotation.rotation0deg;
    const InputImageFormat inputImageFormat = InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: allBytes, metadata: inputImageData);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Escáner QR Continuo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _qrCodes,
                style: TextStyle(fontSize: 16.0, color: Colors.black),
              ),
            ),
          ),
          Expanded(
            child: _cameraController?.value.isInitialized == true
                ? CameraPreview(_cameraController!)
                : Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ContinuousQRScanner(),
  ));
}
