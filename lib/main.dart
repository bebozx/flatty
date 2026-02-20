import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: VoiceAssistant(),
  ));
}

class VoiceAssistant extends StatefulWidget {
  @override
  _VoiceAssistantState createState() => _VoiceAssistantState();
}

class _VoiceAssistantState extends State<VoiceAssistant> {
  // تعريف المحركات
  SpeechToText _speech = SpeechToText();
  FlutterTts _tts = FlutterTts();
  
  // المتغيرات
  bool _isListening = false;
  bool _isSpeaker = true; // التحكم في السبيكر
  String _statusText = "اضغط على الدائرة للبدء";
  String _aiResponse = "";
  List<Map<String, String>> _history = [];

  // رابط نيتلفاي الخاص بك (ضع رابطك هنا بعد الرفع)
  final String netlifyUrl = 'https://assistantbob.netlify.app/.netlify/functions/chat';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  // إعداد محرك النطق
  void _initTts() async {
    await _tts.setLanguage("ar-SA");
    await _tts.setSpeechRate(0.5); // سرعة متوسطة مريحة
    
    // أهم ميزة: الاستماع التلقائي بعد انتهاء الرد
    _tts.setCompletionHandler(() {
      print("انتهى المساعد من الكلام، سأفتح الميكروفون الآن...");
      _startListening();
    });
  }

  // تبديل السبيكر / سماعة الأذن
  void _toggleSpeaker() async {
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
    // في أندرويد و iOS، تحويل الصوت من السبيكر لسماعة المكالمات
    await _tts.setIosAudioCategory(
      _isSpeaker ? IosTextToSpeechAudioCategory.playback : IosTextToSpeechAudioCategory.playAndRecord,
      [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker]
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isSpeaker ? "تم تشغيل السبيكر" : "تم التحويل لسماعة الأذن (السرية)"))
    );
  }

  // بدء الاستماع
  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _statusText = "أنا أسمعك الآن...";
      });
      _speech.listen(
        localeId: "ar-SA",
        onResult: (val) {
          if (val.finalResult) {
            setState(() {
              _isListening = false;
              _statusText = "جاري التفكير...";
            });
            _getAIResponse(val.recognizedWords);
          }
        },
      );
    }
  }

  // إرسال الكلام للذكاء الاصطناعي
  Future<void> _getAIResponse(String userText) async {
    _history.add({"role": "user", "content": userText});

    try {
      final response = await http.post(
        Uri.parse(netlifyUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"messages": _history}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['choices'][0]['message']['content'];
        
        setState(() {
          _aiResponse = reply;
          _history.add({"role": "assistant", "content": reply});
        });

        // المساعد ينطق الرد
        await _tts.speak(reply);
      } else {
        _handleError();
      }
    } catch (e) {
      _handleError();
    }
  }

  void _handleError() {
    setState(() => _statusText = "خطأ في الاتصال");
    _tts.speak("عذراً، حدث خطأ في الاتصال بالإنترنت.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // أسود لراحة العين
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text("رفيقي العربي"),
        actions: [
          // زر السبيكر/السماعة في الأعلى
          IconButton(
            icon: Icon(_isSpeaker ? Icons.volume_up : Icons.phone_in_talk),
            onPressed: _toggleSpeaker,
            tooltip: "تبديل مكان الصوت",
          )
        ],
      ),
      body: Column(
        children: [
          // مساحة لعرض النص
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Text(
                  _aiResponse.isEmpty ? _statusText : _aiResponse,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.amberAccent, // لون مريح ولا يجهد العين
                    fontSize: 26,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
          ),
          
          // الزر الكبير للتحكم
          GestureDetector(
            onTap: () {
              if (!_isListening) _startListening();
            },
            child: Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: _isListening ? Colors.red[900] : Colors.blue[900],
                borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 10),
                  Text(
                    _isListening ? "تحدث الآن" : "اضغط هنا لبدء الحوار",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
