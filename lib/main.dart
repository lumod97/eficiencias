import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;


void main() async {
  // Asegúrate de que la inicialización de Flutter se complete antes de ejecutar cualquier código.
  WidgetsFlutterBinding.ensureInitialized();

  // Obtén la lista de cámaras disponibles antes de ejecutar la app.
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QRCodeScanner(cameras: cameras),
    );
  }
}

class QRCodeScanner extends StatefulWidget {
  final List<CameraDescription> cameras;

  QRCodeScanner({required this.cameras});

  @override
  _QRCodeScannerState createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  late CameraController _cameraController;
  late BarcodeScanner _barcodeScanner;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _barcodeScanner = BarcodeScanner();
  }

  Future<void> _initializeCamera() async {
    final camera = widget.cameras.first;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high, // Puedes ajustar la resolución para optimizar
      enableAudio: false,
    );

    await _cameraController.initialize();
    _cameraController.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _processCameraImage(image);
      }
    });

    setState(() {});
  }

  // Future<void> _processCameraImage(CameraImage image) async {
  //   final WriteBuffer allBytes = WriteBuffer();
  //   for (Plane plane in image.planes) {
  //     allBytes.putUint8List(plane.bytes);
  //   }
  //   final bytes = allBytes.done().buffer.asUint8List();

  //   final Size imageSize =
  //       Size(image.width.toDouble(), image.height.toDouble());

  //   final camera = _cameraController.description;
  //   final imageRotation = InputImageRotationValue.fromRawValue(
  //     camera.sensorOrientation,
  //   );

  //   final inputImageData = InputImageData(
  //     size: imageSize,
  //     imageRotation: imageRotation!,
  //     inputImageFormat:
  //         InputImageFormatValue.fromRawValue(image.format.raw) ?? 
  //         InputImageFormat.nv21,
  //     planeData: image.planes.map(
  //       (Plane plane) {
  //         return InputImagePlaneMetadata(
  //           bytesPerRow: plane.bytesPerRow,
  //           height: plane.height,
  //           width: plane.width,
  //         );
  //       },
  //     ).toList(),
  //   );

  //   final inputImage = InputImage.fromBytes(
  //     bytes: bytes,
  //     inputImageData: inputImageData,
  //   );

  //   try {
  //     final List<Barcode> barcodes =
  //         await _barcodeScanner.processImage(inputImage);

  //     for (Barcode barcode in barcodes) {
  //     // Guardar el frame capturado
  //       await _saveImage(bytes, image.width, image.height, barcode.displayValue);
  //       print('Código QR detectado: ${barcode.displayValue}');
  //     }

  //   } catch (e) {
  //     print('Error procesando la imagen: $e');
  //   } finally {
  //     _isDetecting = false;
  //   }
  // }

  Future<void> _processCameraImage(CameraImage image) async {
  final WriteBuffer allBytes = WriteBuffer();
  for (Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

  final camera = _cameraController.description;
  final imageRotation = InputImageRotationValue.fromRawValue(
    camera.sensorOrientation,
  );

  final inputImageData = InputImageData(
    size: imageSize,
    imageRotation: imageRotation!,
    inputImageFormat: InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21,
    planeData: image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList(),
  );

  final inputImage = InputImage.fromBytes(
    bytes: bytes,
    inputImageData: inputImageData,
  );

  try {
    final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

    for (Barcode barcode in barcodes) {
      // Guardar el frame capturado
      await _saveImage(bytes, image.width, image.height, barcode.displayValue);
      print('Código QR detectado: ${barcode.displayValue}');
    }

  } catch (e) {
    print('Error procesando la imagen: $e');
  } finally {
    _isDetecting = false;
  }
}

  // Future<void> _saveImage(Uint8List bytes, int width, int height, String? valor) async {
  //   try {
  //     final directory = await getExternalStorageDirectory();
  //     final downloadDir = Directory('${directory!.parent.parent.parent.parent.path}/Download/MyQRCodeScans');

  //     if (!await downloadDir.exists()) {
  //       await downloadDir.create(recursive: true);
  //     }

  //     // final timestamp = DateTime.now().millisecondsSinceEpoch;
  //     final filePath = path.join(downloadDir.path, '$valor.png');
  //     // final filePath = path.join(downloadDir.path, 'frame_$timestamp.png');

  //     final file = File(filePath);
  //     await file.writeAsBytes(bytes);

  //     print('Imagen guardada en $filePath');
  //   } catch (e) {
  //     print('Error guardando la imagen: $e');
  //   }
  // }

  Future<void> _saveImage(Uint8List bytes, int width, int height, String? valor) async {
  try {
    final directory = await getExternalStorageDirectory();
    final downloadDir = Directory('${directory!.parent.parent.parent.parent.path}/Download/MyQRCodeScans');

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    // Convierte los bytes de la imagen cruda en una imagen PNG
    final imgImage = img.Image.fromBytes(width, height, bytes);
    final pngBytes = img.encodePng(imgImage);

    final filePath = path.join(downloadDir.path, '$valor.png');
    final file = File(filePath);
    await file.writeAsBytes(pngBytes!);

    print('Imagen guardada en $filePath');
  } catch (e) {
    print('Error guardando la imagen: $e');
  }
}

  @override
  void dispose() {
    _cameraController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          Positioned(
            bottom: 16,
            left: 16,
            child: Text(
              'Escaneando...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
