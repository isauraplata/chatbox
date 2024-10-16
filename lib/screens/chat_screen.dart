import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_gemini/google_gemini.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const apiKey = "AIzaSyCTREetNKiEu4cs1Wp8f8So5t6QJrfTJIs";

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool loading = false;
  bool isConnected = true;
  List<Map<String, String>> textChat = [];
  String userName = "Valeria";

  final TextEditingController _textController = TextEditingController();
  final ScrollController _controller = ScrollController();

  final gemini = GoogleGemini(apiKey: apiKey);

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadChats();
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  void _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatHistory = prefs.getString('chat_history');
    if (chatHistory != null) {
      setState(() {
        textChat = List<Map<String, String>>.from(
          json.decode(chatHistory).map((item) => Map<String, String>.from(item))
        );
      });
    }
  }

  void _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', json.encode(textChat));
  }

  void fromText({required String query}) {
    if (!isConnected) return;

    setState(() {
      loading = true;
      // Agregar el nombre personalizado del emisor
      textChat.add({"role": userName, "text": query});
      _textController.clear();
    });
    _saveChats();
    scrollToTheEnd();

    gemini.generateFromText(query).then((value) {
      setState(() {
        loading = false;
        textChat.add({"role": "Gemini", "text": value.text});
      });
      _saveChats();
      scrollToTheEnd();
    }).onError((error, stackTrace) {
      setState(() {
        loading = false;
        textChat.add({"role": "Gemini", "text": error.toString()});
      });
      _saveChats();
      scrollToTheEnd();
    });
  }

  void scrollToTheEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbox Gemini', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 190, 47, 212),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              setState(() {
                textChat.clear();
              });
              _saveChats();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _controller,
                itemCount: textChat.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  bool isUser = textChat[index]["role"] == userName; // Comparar con el nombre personalizado
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: isUser ? const Color.fromARGB(255, 144, 90, 252) : Colors.grey[300],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: isUser ? Radius.circular(12) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            textChat[index]["role"]!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isUser ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            textChat[index]["text"]!,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Deshabilitar el botón si no hay conexión o si está cargando
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: (isConnected)
                        ? () => fromText(query: _textController.text)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}