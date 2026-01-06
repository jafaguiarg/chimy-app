import 'dart:async';
import 'package:flutter/material.dart';
import '../services/timer_service.dart';
import '../services/settings_service.dart';
import '../utils/time_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TimerService _timerService = TimerService();
  final SettingsService _settingsService = SettingsService();
  
  int _selectedInterval = 15;
  bool _isActive = false;
  DateTime? _nextAnnouncementTime;
  String _currentTime = '';
  Timer? _timeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _updateCurrentTime();
    _startTimeUpdateTimer();
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final interval = await _settingsService.getInterval();
    final isActive = await _settingsService.isActive();
    
    setState(() {
      _selectedInterval = interval;
      _isActive = isActive;
    });

    if (isActive) {
      await _timerService.start();
      _updateNextAnnouncementTime();
    }
  }

  void _startTimeUpdateTimer() {
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCurrentTime();
      if (_isActive) {
        _updateNextAnnouncementTime();
      }
    });
  }

  void _updateCurrentTime() {
    setState(() {
      _currentTime = TimeFormatter.currentMilitaryTime();
    });
  }

  Future<void> _updateNextAnnouncementTime() async {
    final nextTime = await _timerService.getNextAnnouncementTime();
    setState(() {
      _nextAnnouncementTime = nextTime;
    });
  }

  Future<void> _onIntervalChanged(int interval) async {
    setState(() {
      _selectedInterval = interval;
    });
    await _settingsService.setInterval(interval);
    
    // Restart timer if active
    if (_isActive) {
      await _timerService.stop();
      await _timerService.start();
      _updateNextAnnouncementTime();
    }
  }

  Future<void> _onToggleActive() async {
    if (_isActive) {
      await _timerService.stop();
    } else {
      await _timerService.start();
    }
    
    setState(() {
      _isActive = !_isActive;
    });
    
    _updateNextAnnouncementTime();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chimy'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current time display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Text(
                      'Current Time',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentTime,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Interval selector
            const Text(
              'Announcement Interval',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  label: Text('1 min'),
                ),
                ButtonSegment(
                  value: 5,
                  label: Text('5 min'),
                ),
                ButtonSegment(
                  value: 15,
                  label: Text('15 min'),
                ),
                ButtonSegment(
                  value: 30,
                  label: Text('30 min'),
                ),
                ButtonSegment(
                  value: 60,
                  label: Text('60 min'),
                ),
              ],
              selected: {_selectedInterval},
              onSelectionChanged: (Set<int> newSelection) {
                _onIntervalChanged(newSelection.first);
              },
            ),
            const SizedBox(height: 32),
            
            // Next announcement time
            if (_isActive && _nextAnnouncementTime != null)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Next Announcement',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TimeFormatter.toMilitaryTime(_nextAnnouncementTime!),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isActive && _nextAnnouncementTime != null)
              const SizedBox(height: 32),
            
            // Status indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isActive ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Start/Stop button
            ElevatedButton(
              onPressed: _onToggleActive,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isActive ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isActive ? 'Stop' : 'Start',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

