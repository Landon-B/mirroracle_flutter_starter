import 'dart:async';
import 'package:flutter/material.dart';
import '../services/mic_service.dart';

/// Hidden mic debug screen for testing speech recognition.
/// Access via long-press on the Practice button.
class MicDebugPage extends StatefulWidget {
  const MicDebugPage({super.key});

  @override
  State<MicDebugPage> createState() => _MicDebugPageState();
}

class _MicDebugPageState extends State<MicDebugPage> {
  late final MicService _mic;

  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _finalSub;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<Object>? _errSub;
  StreamSubscription<MicState>? _stateSub;

  String _partial = '';
  String _final = '';
  double _level = 0.0;
  MicState _state = MicState.idle;
  Object? _lastErr;

  @override
  void initState() {
    super.initState();
    _mic = MicService();

    _stateSub = _mic.state$.listen((s) {
      setState(() => _state = s);
    });

    _partialSub = _mic.partialText$.listen((t) {
      setState(() => _partial = t);
    });

    _finalSub = _mic.finalText$.listen((t) {
      setState(() => _final = t);
    });

    _levelSub = _mic.soundLevel$.listen((v) {
      setState(() => _level = v);
    });

    _errSub = _mic.errors$.listen((e) {
      setState(() => _lastErr = e);
    });

    _boot();
  }

  Future<void> _boot() async {
    final ok = await _mic.init(debugLogging: true);
    if (!ok) return;

    await _mic.start(
      partialResults: true,
      cancelOnError: false,
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(seconds: 6),
    );
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _finalSub?.cancel();
    _levelSub?.cancel();
    _errSub?.cancel();
    _stateSub?.cancel();

    _mic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mic debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium ?? const TextStyle(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('State: $_state'),
              const SizedBox(height: 8),
              Text('Level: ${(_level * 100).toStringAsFixed(0)}%'),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: _level.clamp(0.0, 1.0)),
              const SizedBox(height: 16),
              const Text('Partial:'),
              Text(_partial, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              const Text('Final:'),
              Text(
                _final,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_lastErr != null) ...[
                const Text('Last error:'),
                Text('$_lastErr', style: const TextStyle(color: Colors.red)),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _mic.stop();
                      },
                      child: const Text('Stop'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await _mic.start(
                          partialResults: true,
                          cancelOnError: false,
                          listenFor: const Duration(minutes: 10),
                          pauseFor: const Duration(seconds: 1),
                        );
                      },
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
