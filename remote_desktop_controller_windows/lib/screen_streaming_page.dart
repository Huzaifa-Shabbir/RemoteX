import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'core/theme/rx_colors.dart';
import 'core/streaming/resize_And_Encode.dart';
import 'core/streaming/streaming_service.dart';
import 'core/streaming/pairing_state.dart';
import 'package:provider/provider.dart';

class ScreenStreamingPage extends StatefulWidget {
  const ScreenStreamingPage({super.key});

  @override
  State<ScreenStreamingPage> createState() => _ScreenStreamingPageState();
}


class _ScreenStreamingPageState extends State<ScreenStreamingPage>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────
  bool _isStreaming = false;
  bool _isTransitioning = false;
  _RefreshRate _selectedRate = _RefreshRate.high;
  _Resolution _selectedResolution = _Resolution.high;
  // Subscription to keep UI in sync with global streaming resolution
  StreamSubscription? _resolutionSub;

  // Live latency simulation
  int _latencyMs = 24;
  Timer? _latencyTimer;

  // Pulsing animation for the green dot while streaming
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // Preview panel controller key
  final GlobalKey<_PreviewPanelState> _previewKey = GlobalKey();

  // ── Helpers ────────────────────────────────────────────────
  int get _currentFps => _selectedRate.fps;

  void _startStreaming() async {
    print('[viewer] Start streaming requested');

    // If no device is paired, ask the user whether to continue or cancel
    final pairing = Provider.of<PairingState>(context, listen: false);
    if (!pairing.isConnected) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No device connected'),
          content: const Text('No device is currently paired. Do you want to continue and start streaming anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        // User cancelled - do not start streaming
        print('[viewer] Start streaming cancelled by user (no paired device)');
        return;
      }
    }

    // Enter transition mode to suppress animations
    setState(() => _isTransitioning = true);

    StreamingService.instance.setTargetFps(_currentFps);
    final started = await StreamingService.instance.start();

    if (started == true) {
      setState(() {
        _isStreaming = true;
        _isTransitioning = false;
      });
      _pulseController.repeat(reverse: true);
      _startLatencyTimer();
      print('[viewer] Streaming started');
    } else {
      // ensure UI reflects not streaming and leave transition mode
      setState(() {
        _isStreaming = false;
        _isTransitioning = false;
      });
      print('[viewer] Streaming failed to start');
    }
  }

  void _stopStreaming() {
    print('[viewer] Stop streaming requested');
    // Enter transition mode to suppress animations while we stop
    setState(() => _isTransitioning = true);
    StreamingService.instance.stop();
    setState(() {
      _isStreaming = false;
      _isTransitioning = false;
    });
    _pulseController.stop();
    _pulseController.reset();
    _stopLatencyTimer();
    print('[viewer] Streaming stopped');
  }

  void _startLatencyTimer() {
    final rng = Random();
    _latencyTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      // Simulate realistic latency fluctuation around the base value
      final base = _selectedRate == _RefreshRate.low
          ? 45
          : _selectedRate == _RefreshRate.medium
              ? 28
              : 18;
      setState(() {
        _latencyMs = base + rng.nextInt(20) - 8;
        if (_latencyMs < 5) _latencyMs = 5;
      });
    });
  }

  void _stopLatencyTimer() {
    _latencyTimer?.cancel();
    _latencyTimer = null;
  }

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _isStreaming = StreamingService.instance.isRunning;
    switch (StreamingService.instance.resolution) {
      case StreamResolution.low:
        _selectedResolution = _Resolution.low;
        break;
      case StreamResolution.medium:
        _selectedResolution = _Resolution.medium;
        break;
      case StreamResolution.high:
      default:
        _selectedResolution = _Resolution.high;
        break;
    }

    _resolutionSub = StreamingService.instance.resolutionStream.listen((res) {
      if (!mounted) return;
      setState(() {
        switch (res) {
          case StreamResolution.low:
            _selectedResolution = _Resolution.low;
            break;
          case StreamResolution.medium:
            _selectedResolution = _Resolution.medium;
            break;
          case StreamResolution.high:
          default:
            _selectedResolution = _Resolution.high;
            break;
        }
      });
    });

    if (_isStreaming) {
      _pulseController.repeat(reverse: true);
      _startLatencyTimer();
    }

    // Listen for streaming status changes so the UI reflects global state.
    StreamingService.instance.statusStream.listen((running) {
      if (!mounted) return;
      setState(() {
        _isStreaming = running;
      });
      if (!running) {
        _pulseController.stop();
        _pulseController.reset();
        _stopLatencyTimer();
      } else {
        _pulseController.repeat(reverse: true);
        _startLatencyTimer();
      }
    });
  }

  @override
  void dispose() {
    _stopLatencyTimer();
    _pulseController.dispose();
    _resolutionSub?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Text(
            'Screen Streaming',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stream your PC screen to your mobile device in real-time',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Main content row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: preview + button ──────────────────────
              Expanded(
                child: Column(
                  children: [
                    _PreviewPanel(
                      key: _previewKey,
                      isStreaming: _isStreaming,
                      isTransitioning: _isTransitioning,
                      pulseAnim: _pulseAnim,
                    ),
                    const SizedBox(height: 0),
                    _BottomBar(
                      isStreaming: _isStreaming,
                      isTransitioning: _isTransitioning,
                      latencyMs: _latencyMs,
                      onStart: _startStreaming,
                      onStop: _stopStreaming,
                      showReset: !_isStreaming && (_previewKey.currentState?.hasImage ?? false),
                      onReset: () => _previewKey.currentState?.resetStream(),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // ── Right: status + rate cards ──────────────────
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    _StreamStatusCard(
                      isStreaming: _isStreaming,
                      fps: _currentFps,
                      selectedResolution: _selectedResolution,
                      onResolutionSelect: (res) {
                        setState(() => _selectedResolution = res);
                        // Immediately update global streaming resolution so processing uses new size
                        final streamRes = switch (res) {
                          _Resolution.low => StreamResolution.low,
                          _Resolution.medium => StreamResolution.medium,
                          _Resolution.high => StreamResolution.high,
                        };
                        StreamingService.instance.setResolution(streamRes);
                      },
                    ),
                    const SizedBox(height: 16),
                    _RefreshRateCard(
                      selected: _selectedRate,
                      onSelect: (rate) {
                        setState(() => _selectedRate = rate);
                        // Update global FPS cap immediately
                        StreamingService.instance.setTargetFps(rate.fps);
                      },
                      isStreaming: _isStreaming,
                    ),
                    const SizedBox(height: 16),
                    _TipCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Preview Panel (now stateful, displays shared-memory frames)
// ─────────────────────────────────────────────────────────────
class _PreviewPanel extends StatefulWidget {
  final bool isStreaming;
  final Animation<double> pulseAnim;
  final bool isTransitioning;

  const _PreviewPanel({
    Key? key,
    required this.isStreaming,
    required this.pulseAnim,
    this.isTransitioning = false,
  }) : super(key: key);

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  ui.Image? image;
  StreamSubscription? _imageSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _imageSub = StreamingService.instance.imageStream.listen((img) {
      if (!mounted) return;
      // Dispose previous image when replaced
      image?.dispose();
      image = img;
      setState(() {});
    }, onError: (e) {
      print('[viewer] [PREVIEW] imageStream error: $e');
    });

    _statusSub = StreamingService.instance.statusStream.listen((running) {
      // no-op for now
    });
  }

  void resetStream() {
    print('[viewer] [DISPLAY] resetStream: clearing retained preview image');
    image?.dispose();
    image = null;
    if (mounted) setState(() {});
  }

  bool get hasImage => image != null;

  @override
  void dispose() {
    print('[viewer] [DISPOSE] dispose: cleaning up preview subscriptions');
    _imageSub?.cancel();
    _statusSub?.cancel();
    // Do not stop the global streaming service here - it is intentionally
    // global so it survives navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      image?.dispose();
      image = null;
    });
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);

    const double previewHeight = 520;

    return AnimatedContainer(
      duration: widget.isTransitioning ? Duration.zero : const Duration(milliseconds: 300),
      width: double.infinity,
      height: previewHeight,
      decoration: BoxDecoration(

        color: c.isDark ? const Color(0xFF1A2535) : const Color(0xFFEFF3F8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border.all(
          color: widget.isStreaming
              ? const Color(0xFF22C55E).withOpacity(0.5)
              : c.dashCardBorder,
        ),
      ),
      child: Stack(
        children: [
          // Live badge
          if (widget.isStreaming)
            Positioned(
              top: 16,
              right: 16,
              child: _LiveBadge(),
            ),

          // Centre content
          Center(
            child: image != null
                ? RawImage(image: image)
                : widget.isStreaming
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Waiting for frames...'),
                        ],
                      )
                    : _IdleContent(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Idle Content (remains unchanged)
// ─────────────────────────────────────────────────────────────
class _IdleContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.desktop_windows_outlined,
          size: 56,
          color: c.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        ),
        const SizedBox(height: 16),
        Text(
          'Preview will appear here when streaming starts',
          style: TextStyle(
            color: c.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Active Content (remains unchanged)
// ─────────────────────────────────────────────────────────────
class _ActiveContent extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _ActiveContent({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing green dot
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withOpacity(0.15 * pulseAnim.value + 0.10),
            ),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0xFF22C55E),
                    const Color(0xFF4ADE80),
                    pulseAnim.value,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Streaming Active',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your screen is being shared',
          style: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Live Badge (remains unchanged)
// ─────────────────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom Bar (button + status row)
// ─────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool isStreaming;
  final bool isTransitioning;
  final int latencyMs;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final bool showReset;
  final VoidCallback? onReset;

  const _BottomBar({
    required this.isStreaming,
    this.isTransitioning = false,
    required this.latencyMs,
    required this.onStart,
    required this.onStop,
    this.showReset = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF1A2535) : const Color(0xFFEFF3F8),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(
          left: BorderSide(
            color: isStreaming
                ? const Color(0xFF22C55E).withOpacity(0.5)
                : c.dashCardBorder,
          ),
          right: BorderSide(
            color: isStreaming
                ? const Color(0xFF22C55E).withOpacity(0.5)
                : c.dashCardBorder,
          ),
          bottom: BorderSide(
            color: isStreaming
                ? const Color(0xFF22C55E).withOpacity(0.5)
                : c.dashCardBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Start / Stop button
          AnimatedSwitcher(
            // suppress the switch animation during quick transitions to avoid flicker
            duration: isTransitioning ? Duration.zero : const Duration(milliseconds: 200),
            child: isStreaming
                ? _StopButton(key: const ValueKey('stop'), onTap: onStop)
                : _StartButton(key: const ValueKey('start'), onTap: onStart),
          ),

          const SizedBox(width: 16),

          // Status row (only when streaming)
          if (isStreaming) ...[
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Connected',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ]),

          ] else if (showReset && onReset != null) ...[
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Stream'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text('Start Streaming'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.stop_rounded, size: 18),
      label: const Text('Stop Streaming'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stream Status Card
// ─────────────────────────────────────────────────────────────
class _StreamStatusCard extends StatelessWidget {
  final bool isStreaming;
  final int fps;
  final _Resolution selectedResolution;
  final ValueChanged<_Resolution> onResolutionSelect;

  const _StreamStatusCard({
    required this.isStreaming,
    required this.fps,
    required this.selectedResolution,
    required this.onResolutionSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.dashCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.dashCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stream Status',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _StatusRow(
            label: 'Status',
            value: isStreaming ? 'Active' : 'Idle',
            valueColor: isStreaming
                ? const Color(0xFF22C55E)
                : c.textSecondary,
          ),
          const SizedBox(height: 16),
          _ResolutionSelector(
            selectedResolution: selectedResolution,
            onSelect: onResolutionSelect,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: c.textSecondary, fontSize: 13)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(
              color: valueColor ?? c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Refresh Rate Card
// ─────────────────────────────────────────────────────────────
enum _RefreshRate { low, medium, high }

extension _RefreshRateX on _RefreshRate {
  String get label => switch (this) {
        _RefreshRate.low    => 'Low',
        _RefreshRate.medium => 'Medium',
        _RefreshRate.high   => 'High',
      };
  int get fps => switch (this) {
        _RefreshRate.low    => 30,
        _RefreshRate.medium => 60,
        _RefreshRate.high   => 120,
      };
}

class _RefreshRateCard extends StatelessWidget {
  final _RefreshRate selected;
  final ValueChanged<_RefreshRate> onSelect;
  final bool isStreaming;

  const _RefreshRateCard({
    required this.selected,
    required this.onSelect,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.dashCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.dashCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.refresh_rounded, size: 16, color: c.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Refresh Rate',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ..._RefreshRate.values.map((rate) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RateOption(
                  rate: rate,
                  isSelected: selected == rate,
                  onTap: () => onSelect(rate),
                ),
              )),
        ],
      ),
    );
  }
}

class _RateOption extends StatefulWidget {
  final _RefreshRate rate;
  final bool isSelected;
  final VoidCallback onTap;

  const _RateOption({
    required this.rate,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RateOption> createState() => _RateOptionState();
}

class _RateOptionState extends State<_RateOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (c.isDark
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFEFF6FF))
                : _hovered
                    ? (c.isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC))
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : c.dashCardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.rate.label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF3B82F6) : c.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Text(
                '${widget.rate.fps} FPS',
                style: TextStyle(
                  color: isSelected ? const Color(0xFF3B82F6) : c.textMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tip Card
// ─────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.isDark
            ? const Color(0xFF1E3A5F).withOpacity(0.5)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isDark
              ? const Color(0xFF2D4F7A)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, height: 1.5),
                children: [
                  TextSpan(
                    text: 'Tip: ',
                    style: TextStyle(
                      color: c.isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: 'Lower refresh rates use less bandwidth and reduce latency.',
                    style: TextStyle(
                      color: c.isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF3B82F6),
                    ),
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

// ─────────────────────────────────────────────────────────────
//  Resolution Selector
// ─────────────────────────────────────────────────────────────
enum _Resolution { low, medium, high }

extension _ResolutionX on _Resolution {
  String get label => switch (this) {
        _Resolution.low    => '480p',
        _Resolution.medium => '720p',
        _Resolution.high   => '1080p',
      };
  String get dimensions => switch (this) {
        _Resolution.low    => '854×480',
        _Resolution.medium => '1280×720',
        _Resolution.high   => '1920×1080',
      };
}

class _ResolutionSelector extends StatelessWidget {
  final _Resolution selectedResolution;
  final ValueChanged<_Resolution> onSelect;

  const _ResolutionSelector({
    required this.selectedResolution,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.aspect_ratio, size: 16, color: c.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Resolution',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        ..._Resolution.values.map((res) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResolutionOption(
                resolution: res,
                isSelected: selectedResolution == res,
                onTap: () => onSelect(res),
              ),
            )),
      ],
    );
  }
}

class _ResolutionOption extends StatefulWidget {
  final _Resolution resolution;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResolutionOption({
    required this.resolution,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ResolutionOption> createState() => _ResolutionOptionState();
}

class _ResolutionOptionState extends State<_ResolutionOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (c.isDark
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFEFF6FF))
                : _hovered
                    ? (c.isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC))
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : c.dashCardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.resolution.label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF3B82F6) : c.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Text(
                widget.resolution.dimensions,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF3B82F6) : c.textMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

