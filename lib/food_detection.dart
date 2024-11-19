import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // 로컬 디렉토리 접근
import 'package:flutter/services.dart'; // rootBundle 사용
import 'package:image/image.dart' as img;

class FoodDetectionPage extends StatefulWidget {
  const FoodDetectionPage({Key? key}) : super(key: key);

  @override
  _FoodDetectionPageState createState() => _FoodDetectionPageState();
}

class _FoodDetectionPageState extends State<FoodDetectionPage> {
  late Interpreter _interpreter; // TensorFlow Lite 인터프리터
  bool _isDetecting = false; // 검출 중 상태 플래그
  List<dynamic>? _results; // 검출 결과
  String _imageCheckResult = ""; // 이미지 경로 확인 결과

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    _interpreter.close(); // 인터프리터 닫기
    super.dispose();
  }

  // TensorFlow Lite 모델 로드
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset("dlmodels/food_detect.tflite");
      print("모델 로드 완료");
    } catch (e) {
      print("모델 로드 실패: $e");
    }
  }

  // Asset 이미지를 로컬 파일로 복사하여 File 객체로 반환
  Future<File> getAssetImageAsFile(String assetPath, String fileName) async {
    try {
      // Asset 데이터 읽기
      final byteData = await rootBundle.load(assetPath);

      // 로컬 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // 로컬 파일 생성 및 저장
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (e) {
      throw Exception("Asset 이미지를 File로 변환하는 데 실패했습니다: $e");
    }
  }

  // 이미지 전처리 함수
  List<List<List<num>>> preprocessImage(File imageFile) {
    final imageBytes = imageFile.readAsBytesSync();
    final image = img.decodeImage(imageBytes)!;

    // 이미지 크기 조정 (224x224로 변경)
    final resizedImage = img.copyResize(image, width: 224, height: 224);

    // RGB 값을 0~1로 정규화하여 리스트로 변환
    final input = List.generate(
      224,
          (y) => List.generate(
        224,
            (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [
            img.getRed(pixel) / 255.0,
            img.getGreen(pixel) / 255.0,
            img.getBlue(pixel) / 255.0,
          ];
        },
      ),
    );

    return input;
  }

  // 이미지 검출 실행
  Future<void> runDetection(File imageFile) async {
    setState(() {
      _isDetecting = true;
    });

    try {
      final input = preprocessImage(imageFile); // 입력 데이터 전처리
      final output = List.filled(10, 0.0).reshape([1, 10]); // 클래스 수에 맞게 수정

      _interpreter.run([input], output); // 모델 추론 실행

      setState(() {
        _isDetecting = false;
        _results = output[0]; // 결과 저장
      });
    } catch (e) {
      print("추론 실패: $e");
      setState(() {
        _isDetecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("처리 가능한 음식물 검출"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          if (_results != null) // 검출 결과 표시
            Expanded(
              child: ListView.builder(
                itemCount: _results!.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text("클래스 $index"),
                    subtitle: Text(
                        "신뢰도: ${(_results![index] * 100).toStringAsFixed(2)}%"),
                  );
                },
              ),
            ),
          if (_isDetecting) // 로딩 인디케이터
            const Center(child: CircularProgressIndicator()),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                const assetPath = "images/testing.png"; // Asset 이미지 경로
                const fileName = "testing.png";

                try {
                  // Asset 이미지를 File 객체로 변환
                  final imageFile = await getAssetImageAsFile(assetPath, fileName);

                  // 파일 경로 확인
                  setState(() {
                    _imageCheckResult = "이미지 파일 생성 완료: ${imageFile.path}";
                  });

                  // 이미지 검출 실행
                  await runDetection(imageFile);
                } catch (e) {
                  setState(() {
                    _imageCheckResult = "이미지 파일 생성 실패: $e";
                  });
                }
              },
              child: const Text("음식물 검출 시작"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _imageCheckResult,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
