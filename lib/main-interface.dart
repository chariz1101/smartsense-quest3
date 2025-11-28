import 'package:flutter/material.dart';
import 'package:smartsense_quest3/display-configuration.dart';
import 'package:smartsense_quest3/about-us.dart';
import 'package:smartsense_quest3/startLocalTranslation.dart';
import 'startTranslation.dart'; // Import the main-interface.dart file

class MainInterface extends StatelessWidget {
  const MainInterface({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E3F8), // Background color (from the image)
      body: Stack( // Use Stack to allow overlapping widgets
        alignment: Alignment.center, // Center the children of the Stack
        children: [
          Positioned(
            top: 80, // Adjust this value to control the vertical position of the image
            child: Image.asset(
              'assets/purple-glasses.png', // Replace with your image path
              width: 150,
              height: 150,
              fit: BoxFit.contain, // Or BoxFit.cover, BoxFit.fitWidth, etc.
            ),
          ),
          Positioned(
            top: 180, // Adjust this value to control the vertical position of the text
            child: Text(
              'SMARTSENSE',
              style: const TextStyle(
                fontFamily: 'SmartSense',
                fontSize: 32, // Approximate size
                color: Color(0xFF49225B), // Primary purple color (from the image)
              ),
            ),
          ),
          Positioned(
            top: 220, // Adjust this value to position the battery and device status
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Battery Remaining: 50%',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Color(0xFF49225B),
                    ),
                  ),
                  const SizedBox(height: 0),
                  const Text(
                    'Device Status: Not Connected',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Color(0xFF49225B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 320, // Adjust this value to position the first button
            child: SizedBox(
              width: 210,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LocalTranscriptionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0xFF763B8D),
                        Color(0xFF211027),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'START LOCAL TRANSCRIPTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Manrope',
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 381, // Adjust this value to position the second button
            child: SizedBox(
              width: 210,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TranscriptionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF49225B).withOpacity(0.63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                  ),
                ),
                child: const Text('START CLOUD TRANSCRIPTION'),
              ),
            ),
          ),
          Positioned(
            top: 442, // Adjust this value to position the third button
            child: SizedBox(
              width: 210,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DisplayConfigurationScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF49225B).withOpacity(0.63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                  ),
                ),
                child: const Text('CONFIGURE DISPLAY'),
              ),
            ),
          ),
          Positioned(
            top: 503, // Adjust this value to position the fourth button
            child: SizedBox(
              width: 210,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutUsScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF49225B).withOpacity(0.63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                  ),
                ),
                child: const Text('ABOUT US'),
              ),
            ),
          ),
          const Positioned(
            bottom: 16.0,
            child: Text(
              '© SMARTSENSE 2025',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                color: Color(0xFF49225B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}