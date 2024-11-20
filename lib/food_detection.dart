import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class FoodDetectionPage extends StatefulWidget {
  @override
  _FoodDetectionPageState createState() => _FoodDetectionPageState();
}

class _FoodDetectionPageState extends State<FoodDetectionPage> {
  late Interpreter _interpreter; // TensorFlow Lite 모델 인터프리터
  late List<String> _labels; // 라벨 리스트
  late CameraController _cameraController; // 카메라 컨트롤러
  bool _isDetecting = false; // 디텍션 상태 플래그
  List<Map<String, dynamic>> _detections = []; // 디텍션 결과 저장

  @override
  void initState() {
    super.initState();
    initializeCamera(); // 카메라 초기화
    loadModel(); // 모델 로드
    loadLabels(); // 라벨 로드
  }

  @override
  void dispose() {
    _cameraController.dispose(); // 카메라 컨트롤러 해제
    _interpreter.close(); // 인터프리터 해제
    super.dispose();
  }

  // 카메라 초기화
  Future<void> initializeCamera() async {
    final cameras = await availableCameras(); // 사용 가능한 카메라 리스트
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium); // 첫 번째 카메라 사용
    await _cameraController.initialize(); // 카메라 초기화
    _cameraController.startImageStream(processCameraImage); // 카메라 프레임 스트림 처리
    setState(() {});
  }

  // TensorFlow Lite 모델 로드
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset("dlmodels/food_detect.tflite"); // 모델 로드
      print("Model loaded successfully.");
    } catch (e) {
      print("Failed to load model: $e"); // 에러 처리
    }
  }

  // 라벨 로드
  Future<void> loadLabels() async {
    try {
      final labelData = await DefaultAssetBundle.of(context)
          .loadString("dlmodels/food_labelmap.txt"); // 라벨 파일 로드
      _labels = labelData.split('\n').where((label) => label.isNotEmpty).toList(); // 라벨 리스트 생성
      print("Labels loaded: ${_labels.length}");
    } catch (e) {
      print("Failed to load labels: $e"); // 에러 처리
    }
  }

  // 카메라 프레임 처리
  void processCameraImage(CameraImage image) async {
    if (_isDetecting) return; // 현재 디텍션 중이면 무시

    _isDetecting = true; // 디텍션 상태 설정

    try {
      final input = preprocessCameraImage(image); // 입력 이미지 전처리
      // 모델 출력 텐서 초기화
      final outputBoxes = List.filled(10 * 4, 0.0).reshape([1, 10, 4]); // 바운딩 박스 좌표
      final outputClasses = List.filled(10, 0.0).reshape([1, 10]); // 클래스
      final outputScores = List.filled(10, 0.0).reshape([1, 10]); // 신뢰도

      // 모델 추론 실행
      _interpreter.runForMultipleInputs(input, {
        0: outputBoxes,
        1: outputClasses,
        2: outputScores,
      });

      // 디텍션 결과 처리
      final detections = <Map<String, dynamic>>[];
      for (int i = 0; i < 10; i++) {
        final score = outputScores[0][i]; // 신뢰도
        if (score > 0.7) { // 신뢰도 70% 이상만 처리
          final categoryIndex = outputClasses[0][i].toInt(); // 클래스 인덱스
          final category = _labels[categoryIndex]; // 클래스 이름
          final box = outputBoxes[0][i]; // 바운딩 박스 좌표
          detections.add({
            "category": category, // 디텍션 클래스
            "score": score, // 신뢰도
          });
        }
      }

      // 디텍션 결과 저장
      setState(() {
        _detections = detections;
      });
    } catch (e) {
      print("Error processing camera image: $e"); // 에러 처리
    } finally {
      _isDetecting = false; // 디텍션 상태 해제
    }
  }

  Uint8List preprocessCameraImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    // YUV420 데이터를 RGB로 변환 (패키지 사용 가능)
    final Uint8List rgbData = Uint8List(width * height * 3);
    for (int i = 0; i < width * height; i++) {
      // YUV420 -> RGB 변환 논리 추가 (간단한 예시)
      rgbData[i * 3] = image.planes[0].bytes[i]; // R
      rgbData[i * 3 + 1] = image.planes[1].bytes[i ~/ 4]; // G
      rgbData[i * 3 + 2] = image.planes[2].bytes[i ~/ 4]; // B
    }

    // 이미지 크기 조정 및 정규화 (300x300 크기로)
    final Uint8List resizedData = Uint8List(300 * 300 * 1);
    for (int i = 0; i < resizedData.length; i++) {
      resizedData[i] = (rgbData[i] / 255.0).toInt(); // 정규화된 값
    }

    return resizedData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Food Detection Page"),
      ),
      body: Stack(
        children: [
          // 카메라 프리뷰
          if (_cameraController.value.isInitialized)
            CameraPreview(_cameraController),
          // 디텍션 결과
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: EdgeInsets.all(16.0),
              child: Text(
                _detections.isNotEmpty
                    ? _detections
                    .map((d) =>
                "${d['category']}: ${(d['score'] * 100).toStringAsFixed(1)}%")
                    .join("\n")
                    : "No detections found.",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
