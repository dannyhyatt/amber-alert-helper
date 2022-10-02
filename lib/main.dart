import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
// import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: const MyHomePage(title: 'Amber Alert Helper Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String texts = 'Press Camera button to get started';
  CameraImage? _cameraImage;
  bool _buttonPressed = false;
  String plate = "No plate right now";
  late BuildContext _ctx;

  void _incrementCounter() {
    if (_buttonPressed) return;
    _buttonPressed = true;
    () async {
      print('running');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseDatabase database = FirebaseDatabase.instance;
      database.ref().get().then((value) {
        plate = value.value.toString();

        setState(() {
          if (plate != "No plate right now") {
            plate = plate.substring(8, plate.length - 1);
          }
        });
        print(plate);
      });
      // try {

      // final functions = FirebaseFunctions.instance;
      // try {
      //   final result =
      //       await FirebaseFunctions.instance.httpsCallable('helloWorld').call();
      //   print('result: ${result.data}');
      // } on FirebaseFunctionsException catch (error) {
      //   print(error.code);
      //   print(error.details);
      //   print(error.message);
      // }

      // final fcmToken = await FirebaseMessaging.instance.getToken();
      // print('token $fcmToken');

      // FirebaseMessaging.onBackgroundMessage(
      //     (message) async => print('MESSAGE ${message.data}'));
      // FirebaseMessaging.onMessage
      //     .listen((RemoteMessage msg) async => print('message: ${msg.data}'));
      // FirebaseMessaging.instance.requestPermission();

      CameraController? _camera;

      List<CameraDescription> cameras = await availableCameras();

      _camera = CameraController(cameras[0], ResolutionPreset.low,
          imageFormatGroup: ImageFormatGroup.bgra8888);

      print('ready to start');
      // ImagePicker picker = ImagePicker();
      // XFile? file = await picker.pickImage(source: ImageSource.gallery);
      // print('file location: ${(file!.path)}');
      await _camera.initialize();
      _camera.startImageStream((image) => _cameraImage = image);

      final InputImage inputImage;
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      Timer t = Timer.periodic(const Duration(seconds: 1), (timer) async {
        InputImage? img = getInputImage(_cameraImage);
        if (img == null || timer.tick < 5) return;

        final RecognizedText recognizedText =
            await textRecognizer.processImage(img);

        String text = recognizedText.text;
        for (TextBlock block in recognizedText.blocks) {
          final Rect rect = block.boundingBox;
          final cornerPoints = block.cornerPoints;
          final String text = block.text;
          final List<String> languages = block.recognizedLanguages;

          print('made it here');
          texts = '';
          for (TextLine line in block.lines) {
            // Same getters as TextBlock
            // for (TextElement element in line.elements) {
            //   // Same getters as TextBlock
            print('TEXTS: ${line.text}');
            texts += '${line.text}\n';
            // }
          }
          print('plate: $plate');
          print('texts: ${texts.replaceAll(' ', '').replaceAll('-', '')}');
          if (texts.replaceAll(' ', '').replaceAll('-', '').contains(plate)) {
            print("FOUND");
            // show the dialog
            FirebaseDatabase.instance.ref().update({"found": true});
            showDialog(
              context: _ctx,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Found plate!"),
                  content: Text(
                      "Thank you for using Amber alert helper, we have reported your sighting."),
                  actions: [
                    TextButton(
                      child: Text("OK"),
                      onPressed: () {},
                    ),
                  ],
                );
                ;
              },
            );
          }
          setState(() {});
        }
      });

      setState(() {
        texts = 'Ready to scan';
      });
      textRecognizer.close();
    }();
  }

  @override
  Widget build(BuildContext context) {
    _ctx = context;
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Looking for plate: ${plate}',
            ),
            Text(
              texts != "Ready to scan" ? 'Found: ${texts}' : texts,
            ),
          ],
        ),
      ),
      floatingActionButton: _buttonPressed
          ? Container()
          : FloatingActionButton(
              onPressed: _incrementCounter,
              tooltip: 'Increment',
              child: const Icon(Icons.camera_alt),
            ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  InputImage? getInputImage(CameraImage? cameraImage) {
    if (cameraImage == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());

    final InputImageRotation imageRotation = InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat = InputImageFormat.bgra8888;

    final planeData = cameraImage.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
  }
}
