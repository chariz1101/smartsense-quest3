import 'dart:async';
import 'dart:convert'; // For JSON decoding
import 'dart:io'; // REQUIRED: To check directory structure

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED: For rootBundle check
import 'package:vosk_flutter/vosk_flutter.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalTranscriptionScreen extends StatefulWidget {
  const LocalTranscriptionScreen({super.key});

  @override
  State<LocalTranscriptionScreen> createState() => _LocalTranscriptionScreenState();
}

class _LocalTranscriptionScreenState extends State<LocalTranscriptionScreen> {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  // Controllers
  final ScrollController _scrollController = ScrollController();

  // State
  String _status = 'Initializing Model...';
  String _transcribedText = '';
  String _interimText = '';
  bool _isRecognizing = false;
  bool _modelLoaded = false;

  // --- Display Settings State ---
  double _displayTextSize = 16.0;
  Color _displayTextColor = Colors.black;
  TextAlign _displayTextAlignment = TextAlign.center;
  Alignment _displayContainerAlignment = Alignment.center;

  // --- MODEL PATH CONFIGURATION ---
  // Ensure this matches your pubspec.yaml asset exactly
  final String _modelAssetPath = 'assets/models/smartsense_model.zip';

  @override
  void initState() {
    super.initState();
    _loadDisplaySettings();
    _initVosk();
  }

  Future<void> _loadDisplaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _displayTextSize = prefs.getDouble('textSize') ?? 16.0;
      
      int? colorVal = prefs.getInt('textColorValue');
      _displayTextColor = colorVal != null ? Color(colorVal) : Colors.black;

      String alignString = prefs.getString('textAlignment') ?? 'center';

      if (alignString.contains('Start')) {
        _displayTextAlignment = TextAlign.left;
      } else if (alignString.contains('End')) {
        _displayTextAlignment = TextAlign.right;
      } else {
        _displayTextAlignment = TextAlign.center;
      }

      switch (alignString) {
        case 'topStart': _displayContainerAlignment = Alignment.topLeft; break;
        case 'topCenter': _displayContainerAlignment = Alignment.topCenter; break;
        case 'topEnd': _displayContainerAlignment = Alignment.topRight; break;
        case 'centerStart': _displayContainerAlignment = Alignment.centerLeft; break;
        case 'center': _displayContainerAlignment = Alignment.center; break;
        case 'centerEnd': _displayContainerAlignment = Alignment.centerRight; break;
        case 'bottomStart': _displayContainerAlignment = Alignment.bottomLeft; break;
        case 'bottomCenter': _displayContainerAlignment = Alignment.bottomCenter; break;
        case 'bottomEnd': _displayContainerAlignment = Alignment.bottomRight; break;
        default: _displayContainerAlignment = Alignment.center;
      }
    });
  }

  Future<void> _initVosk() async {
    // 1. Check Permissions
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _status = 'Mic Permission Denied');
      return;
    }

    try {
      setState(() => _status = 'Verifying Asset Bundle...');

      // --- DIAGNOSTIC CHECK (With Size) ---
      try {
        final byteData = await rootBundle.load(_modelAssetPath);
        debugPrint("✅ Asset found in bundle: $_modelAssetPath");
        debugPrint("📦 Size: ${(byteData.lengthInBytes / 1024 / 1024).toStringAsFixed(2)} MB");
        
        if (byteData.lengthInBytes < 1000) {
           throw Exception("File is too small (Empty?). Check the zip file.");
        }
      } catch (e) {
        debugPrint("Asset Load Error: $e");
        throw Exception("ASSET NOT FOUND IN BUNDLE. Check pubspec.yaml indentation or filename.");
      }
      // ------------------------------------

      setState(() => _status = 'Extracting Model...');
      
      // 2. Load Model from Assets (Extracts the ZIP)
      String modelPath = await ModelLoader().loadFromAssets(_modelAssetPath);
      
      // 3. INTELLIGENT PATH CORRECTION
      final dir = Directory(modelPath);
      
      if (!await dir.exists()) {
        debugPrint("⚠️ Target directory missing: $modelPath");
        
        // CHECK PARENT (The Flattened Zip Fix - IMPROVED LOGIC)
        // Previous method failed on directory names, this method checks paths directly.
        final parentDir = dir.parent;
        if (await parentDir.exists()) {
           final children = parentDir.listSync();
           debugPrint("📂 Scanning parent directory: ${parentDir.path}");
           
           // Robust check for 'conf' folder regardless of path separator
           bool hasConf = children.any((e) => e.path.endsWith("/conf") || e.path.endsWith("\\conf") || e.path.endsWith("conf"));
           
           if (hasConf) {
             debugPrint("✅ Found 'conf' in parent directory. Using parent path.");
             modelPath = parentDir.path;
           } else {
             throw FileSystemException("Extraction failed. 'conf' folder not found in parent.", modelPath);
           }
        } else {
           throw FileSystemException("Extraction failed. Parent directory missing.", modelPath);
        }
      } else {
        // Standard check for nested wrapper folder (e.g. model/model/conf)
        final List<FileSystemEntity> children = dir.listSync();
        if (children.length == 1 && children.first is Directory) {
          debugPrint("📂 Detected nested model folder: ${children.first.path}");
          modelPath = children.first.path;
        }
      }

      debugPrint("🚀 Loading Model from: $modelPath");
      _model = await _vosk.createModel(modelPath);
      
      // 4. Create Recognizer
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );

      // 5. Create Speech Service
      if (_recognizer != null) {
        _speechService = await _vosk.initSpeechService(_recognizer!);
        _setupListeners();
        setState(() {
          _modelLoaded = true;
          _status = 'Ready (Offline)';
        });
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains("ASSET NOT FOUND")) {
        setState(() => _status = 'Error: zip file not found in assets.');
      } else {
        setState(() => _status = 'Load Failed: $e');
      }
    }
  }

  void _setupListeners() {
    _speechService!.onPartial().listen((partialJson) {
      Map<String, dynamic> data = jsonDecode(partialJson);
      setState(() {
        _interimText = data['partial'] ?? '';
      });
    });

    _speechService!.onResult().listen((resultJson) {
      Map<String, dynamic> data = jsonDecode(resultJson);
      String text = data['text'] ?? '';
      if (text.isNotEmpty) {
        setState(() {
          _transcribedText += '$text\n';
          _interimText = '';
          _scrollToBottom();
        });
      }
    });
  }

  Future<void> _startRecognition() async {
    if (_speechService != null) {
      await _speechService!.start();
      setState(() {
        _isRecognizing = true;
        _status = 'Listening (On-Device)...';
      });
    }
  }

  Future<void> _stopRecognition() async {
    if (_speechService != null) {
      await _speechService!.stop();
      setState(() {
        _isRecognizing = false;
        _status = 'Ready (Offline)';
        if (_interimText.isNotEmpty) {
           _transcribedText += '$_interimText\n';
           _interimText = '';
           _scrollToBottom();
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _speechService?.stop();
    _speechService?.dispose();
    _model?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic background color: Black if text is white, otherwise White
    final Color boxBackgroundColor = _displayTextColor == Colors.white ? Colors.black : Colors.white;

    final BoxDecoration displayBoxDecoration = BoxDecoration(
      color: boxBackgroundColor, 
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(25, 0, 0, 0),
          spreadRadius: 2,
          blurRadius: 5,
          offset: const Offset(0, 3),
        ),
      ],
    );

    // Style for LIVE text
    final TextStyle liveTextStyle = TextStyle(
      fontFamily: 'Manrope',
      fontSize: _displayTextSize,
      color: _displayTextColor,
      fontWeight: FontWeight.normal,
    );

    // Style for HISTORY text
    final TextStyle historyTextStyle = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 12.0, 
      color: _displayTextColor,
      fontWeight: FontWeight.normal,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2E3F8), // Match main app background
      appBar: AppBar(
        title: const Text(
          'Local Transcription',
          style: TextStyle(fontFamily: 'Manrope', color: Color(0xFF49225B), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF49225B)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Status Text
            Text(
              'Status: $_status', 
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: _status.contains('Error') || _status.contains('Failed') || _status.contains('Denied') 
                    ? Colors.redAccent 
                    : const Color(0xFF49225B),
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // --- LIVE LISTENING BOX ---
            Expanded(
              flex: 3, 
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: displayBoxDecoration.copyWith(
                  border: _isRecognizing 
                      ? Border.all(color: const Color(0xFF763B8D), width: 2) 
                      : null,
                ),
                child: Align(
                  alignment: _displayContainerAlignment, 
                  child: SingleChildScrollView(
                    child: Text(
                      _interimText.isEmpty && !_isRecognizing
                          ? 'Press START to speak...'
                          : _interimText.isEmpty
                              ? '...Listening...'
                              : _interimText,
                      style: liveTextStyle.copyWith(
                        color: (_interimText.isEmpty && !_isRecognizing) 
                            ? Colors.grey 
                            : _displayTextColor
                      ),
                      textAlign: _displayTextAlignment, 
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Transcript History:',
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF49225B),
                fontFamily: 'Manrope'
              ),
            ),
            const SizedBox(height: 8),
            
            // --- HISTORY BOX ---
            Expanded(
              flex: 1, 
              child: Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: displayBoxDecoration,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Text(
                    _transcribedText.isEmpty ? 'The full transcription will appear here.' : _transcribedText,
                    style: historyTextStyle.copyWith(
                       color: _transcribedText.isEmpty ? Colors.grey : _displayTextColor
                    ),
                    textAlign: TextAlign.center, // Forced Center Alignment
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            Center(
              child: SizedBox(
                width: 280, 
                height: 50,
                child: ElevatedButton.icon(
                  // Button only enabled if model is successfully loaded
                  onPressed: _modelLoaded 
                      ? (_isRecognizing ? _stopRecognition : _startRecognition)
                      : null,
                  icon: Icon(_isRecognizing ? Icons.stop : Icons.mic, color: Colors.white),
                  label: Text(
                    _isRecognizing ? 'STOP LISTENING' : 'START LISTENING',
                    style: const TextStyle(
                      fontFamily: 'Manrope', 
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecognizing 
                        ? Colors.redAccent.shade700 
                        : (_modelLoaded ? const Color(0xFF763B8D) : Colors.grey),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}