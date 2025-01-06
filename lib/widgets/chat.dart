import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:nimbus/gemini.dart';
import 'package:nimbus/widgets/common.dart';

import '../user_store.dart';

class ChatPage extends StatefulWidget {
  final Chat? chat; // No chat = new chat
  const ChatPage([this.chat]);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Chat chat;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _userHasScrolled = false;

  // returns when the message completes
  Future<void> sendMessage({
    required List<Message> allMessages,
    required String content,
  }) async {
    final emptyChat = widget.chat == null && allMessages.isEmpty;
    if (emptyChat) await UserStore.instance.saveChat(chat);
    final userMessage = new Message(content: content);
    await UserStore.instance.saveMessage(chat, userMessage);
    _userHasScrolled = false;
    scrollToLastMessage();
    final aiMessage = new Message(
        content: '', model: UserStore.instance.model, waiting: true);
    await UserStore.instance.saveMessage(chat, aiMessage);
    final subscription = GeminiClient.instance
        .chatCompleteStream(allMessages, userMessage)
        .listen((chatResult) async {
      aiMessage.content = chatResult.content;
      await UserStore.instance.saveMessage(chat, aiMessage);
      scrollToLastMessage();
    });
    // equivalent to onDone and onError
    try {
      await subscription.asFuture();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Error $e')),
      );
      aiMessage.error = e.toString();
    } finally {
      aiMessage.waiting = false;
      await UserStore.instance.saveMessage(chat, aiMessage);
    }
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      _userHasScrolled = true;
    }
  }

  void scrollToLastMessage() {
    if (_scrollController.hasClients && !_userHasScrolled) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.chat == null) {
      chat = Chat();
    } else {
      chat = widget.chat!;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FirestoreQueryBuilder<Message>(
        query: UserStore.instance.readChatMessages(chat),
        builder: (context, snapshot, _) {
          if (snapshot.isFetching) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasMore) snapshot.fetchMore();

          final itemCount = snapshot.docs.length;
          final allMessages = snapshot.docs.map((doc) => doc.data()).toList();
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: CommonAppBar(chat: allMessages.isEmpty ? null : chat),
            drawer: CommonDrawer(chat: allMessages.isEmpty ? null : chat),
            body: Container(
              padding: EdgeInsets.all(25),
              child: Column(
                children: [
                  Expanded(
                      child: ListView.builder(
                          controller: _scrollController,
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            // Schedule a post-frame callback to scroll to bottom
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              scrollToLastMessage();
                            });
                            final Message message = allMessages[index];
                            return message.isUser()
                                ? UserMessage(message: message)
                                : AIMessage(message: message, chat: chat);
                          })),
                  const SizedBox(height: 15),
                  // bind allMessages
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () {
                            if (_inputController.text.trim().isNotEmpty) {
                              sendMessage(
                                allMessages: allMessages,
                                content: _inputController.text,
                              );
                              _inputController.clear();
                            }
                          },
                        ),
                      ),
                      onSubmitted: (content) {
                        if (content.trim().isNotEmpty) {
                          sendMessage(
                            allMessages: allMessages,
                            content: content,
                          );
                          _inputController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

class UserMessage extends StatelessWidget {
  final Message message;

  const UserMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 30),
      child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.7,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: EdgeInsets.all(15.0),
                padding: EdgeInsets.all(15.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: SelectableText(message.content),
              ),
            ),
          )),
    );
  }
}

class AIMessage extends StatelessWidget {
  final Message message;
  final Chat chat;

  const AIMessage({required this.message, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(5),
            margin: EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.grey,
                width: 0.2,
              ),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 20,
              height: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: message.content,
                  // TODO selectability is choppy, how can we fix that?
                  selectable: true,
                  extensionSet: md.ExtensionSet.gitHubWeb,
                ),
                if (message.waiting)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: SizedBox(
                      width: 7.0,
                      height: 7.0,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
