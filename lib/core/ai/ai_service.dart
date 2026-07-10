import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

abstract class AIService {
  Future<void> initialize();
  Stream<String> sendMessage(String text);
  bool get isReady;
  InferenceChat get chat;
  void dispose();
}

class GemmaAIService implements AIService {
  InferenceModel? _model;
  InferenceChat? _chat;
  bool _ready = false;

  @override
  bool get isReady => _ready;

@override
  InferenceChat get chat => _chat!;

  // Тулы — задачи, которые модель может вызвать
  static final List<Tool> _tools = [
    Tool(
      name: 'create_task',
      description: 'Creates a new task in the tracker.',
      parameters: {
        'type': 'object',
        'properties': {
          'title':       {'type': 'string', 'description': 'Task title'},
          'description': {'type': 'string', 'description': 'Details'},
          'priority':    {'type': 'string', 'enum': ['low', 'medium', 'high']},
          'due_date':    {'type': 'string', 'description': 'ISO 8601 date'},
          'starts_at':    {'type': 'string', 'description': 'ISO 8601 date'},

        },
        'required': ['title'],
      },
    ),
    Tool(
      name: 'list_tasks',
      description: 'Returns tasks matching the filter.',
      parameters: {
        'type': 'object',
        'properties': {
          'filter': {'type': 'string', 'enum': ['all', 'today', 'overdue']},
        },
      },
    ),
    Tool(
      name: 'complete_task',
      description: 'Marks a task as done.',
      parameters: {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'},
        },
        'required': ['task_id'],
      },
    ),
  ];

  @override
  Future<void> initialize() async {
    try {
      _model = await FlutterGemma.getActiveModel(
        preferredBackend: PreferredBackend.cpu,
        maxTokens: 2048);
      _chat = await _model!.createChat(
        supportsFunctionCalls: true,
        tools: _tools,
      );
      _ready = true;
    } catch (e) {
      debugPrint('Model not ready yet, waiting for installation: $e');
      _ready = false;
    }
  }

  @override
  Stream<String> sendMessage(String text) async* {
    if (_chat == null) throw StateError('AIService not initialized');

    await _chat!.addQueryChunk(Message.text(text: text, isUser: true));

    

    await for (final response in 
    _chat!.generateChatResponseAsync()
    ) {
      if (response is TextResponse) {
        yield response.token;
      } else if (response is FunctionCallResponse) {
        // Возвращаем специальный маркер для ViewModel
        yield '__FUNCTION_CALL__:${response.name}:${jsonEncode(response.args)}';
      }
    }
    

  }

  @override
  void dispose() {
    _chat?.close();
    _model?.close();
    _ready = false;
  }
}