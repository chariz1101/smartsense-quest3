import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart'; 
import 'package:web_socket_channel/io.dart';
import 'package:permission_handler/permission_handler.dart';

// --- CONFIGURATION ---
// Ensure this matches the output of: gcloud run services describe ...
const String websocketUrl = 'wss://quest-transcriber-523298308672.asia-southeast1.run.app'; 
const int sampleRate = 16000;
const int channels = 1; // Mono
// --- END CONFIGURATION ---

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  IOWebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSubscription;
  final AudioRecorder _audioRecorder = AudioRecorder(); 
  
  String _status = 'Initializing...';
  String _transcribedText = ''; 
  String _interimText = ''; 

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndConnect();
  }

  Future<void> _requestPermissionsAndConnect() async {
    debugPrint("🔍 Checking permissions...");
    setState(() => _status = 'Requesting Mic Permission...');
    
    var status = await Permission.microphone.request();
    
    if (status.isGranted) {
      debugPrint("✅ Permission Granted. Connecting to server...");
      _connectWebSocket();
    } else {
      debugPrint("❌ Permission Denied.");
      setState(() => _status = 'Mic Permission Denied. Check Settings.');
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  void _connectWebSocket() {
    try {
      debugPrint("🔵 Connecting to: $websocketUrl");
      _channel = IOWebSocketChannel.connect(Uri.parse(websocketUrl));
      
      setState(() => _status = 'Connecting...');
      
      _channel!.stream.listen(
        (message) {
          debugPrint("⬇️ RECEIVED: $message");
          if (!_status.contains('Connected')) {
             setState(() => _status = 'Connected & Transcribing');
          }
          _handleTranscription(message.toString());
        },
        onDone: () {
          debugPrint("🔶 WebSocket Closed by Server");
          setState(() {
            _status = 'Disconnected (Server Closed)';
            _stopStreaming();
          });
        },
        onError: (error) {
          debugPrint("❌ WebSocket Error: $error");
          setState(() {
            _status = 'Connection Error. Retrying...';
            _stopStreaming();
            Future.delayed(const Duration(seconds: 5), _connectWebSocket);
          });
        },
      );

    } catch (e) {
      debugPrint("❌ Connection Failed Exception: $e");
      setState(() => _status = 'Failed to connect: $e');
      Future.delayed(const Duration(seconds: 5), _connectWebSocket);
    }
  }

  void _handleTranscription(String message) {
    if (!mounted) return;

    bool isFinal = message.endsWith('.') || message.endsWith('?') || message.endsWith('!');
    
    setState(() {
      if (isFinal) {
        _transcribedText += '$_interimText $message\n'; 
        _interimText = ''; 
      } else {
        _interimText = message; 
      }
    });
  }

  Future<void> _startStreaming() async {
    if (_channel == null) {
      debugPrint("⚠️ WebSocket null, reconnecting...");
      _connectWebSocket();
      return;
    }

    if (await _audioRecorder.isRecording()) {
      return;
    }

    try {
      debugPrint("🎙️ Initializing Mic Stream...");
      
      final micStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits, 
          sampleRate: sampleRate,
          numChannels: channels,
        ),
      );

      _micSubscription = micStream.listen((audioChunk) {
        // FIX: Uncommented this line so you can see data flowing in the logs!
        debugPrint("🎤 Mic captured ${audioChunk.length} bytes");
        try {
          _channel!.sink.add(audioChunk); 
        } catch (e) {
          debugPrint("❌ Error sending bytes: $e");
        }
      }, onError: (e) {
        debugPrint("❌ Mic Stream Error: $e");
        setState(() => _status = 'Mic Stream Error: $e');
        _stopStreaming();
      });

      setState(() {
        _status = 'Streaming Audio...';
        _transcribedText = ''; 
        _interimText = '';
        _channel!.sink.add('START_STREAMING'); 
      });
      debugPrint("✅ Audio Streaming Started");

    } catch (e) {
      debugPrint("❌ Start Stream Exception: $e");
      setState(() => _status = 'Audio setup failed: $e');
      _stopStreaming();
    }
  }

  void _stopStreaming() async {
    debugPrint("🛑 Stopping Stream...");
    _micSubscription?.cancel();
    _micSubscription = null;
    await _audioRecorder.stop();
    
    try {
      if (_channel != null) {
        _channel!.sink.add('STOP_STREAMING'); 
      }
    } catch (e) {
      // Ignore errors sending stop
    }
    
    if (mounted) {
      setState(() {
        _status = 'Ready to Start';
        if (_interimText.isNotEmpty) {
          _transcribedText += '$_interimText (Stopped)\n';
          _interimText = '';
        }
      });
    }
  }
  
  @override
  void dispose() {
    _stopStreaming();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStreaming = _micSubscription != null; 
    final isConnected = !_status.contains('Error') && !_status.contains('Disconnected');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest 3 Real-time ASR'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Status: $_status', 
              style: TextStyle(
                color: _status.contains('Error') || _status.contains('Denied') ? Colors.redAccent : Colors.lightGreenAccent,
                fontWeight: FontWeight.bold
              )
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isStreaming ? Colors.yellow.shade700 : Colors.blueGrey.shade800,
                  width: isStreaming ? 3 : 1,
                ),
              ),
              child: Text(
                _interimText.isEmpty && !isStreaming
                    ? 'Press START to speak...'
                    : _interimText.isEmpty
                        ? '...Listening...'
                        : _interimText,
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.w500,
                  color: isStreaming ? Colors.yellowAccent : Colors.blueGrey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Transcript History:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(top: 8),
                child: SingleChildScrollView(
                  child: Text(
                    _transcribedText.isEmpty ? 'The full transcription will appear here.' : _transcribedText,
                    style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            Center(
              child: ElevatedButton.icon(
                onPressed: isStreaming ? _stopStreaming : isConnected ? _startStreaming : null,
                icon: Icon(isStreaming ? Icons.stop : Icons.mic, size: 30),
                label: Text(
                  isStreaming ? 'STOP STREAMING' : 'START STREAMING',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStreaming ? Colors.redAccent.shade700 : isConnected ? Colors.green.shade700 : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}