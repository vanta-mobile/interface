import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

import '../../../core/theme.dart';

/// Plays the approved Vanta Rive intro once over the native launch
/// background, whose plain `#121215` matches the animation's first frame.
/// Without [onIntroCompleted] it shows the final frame while startup work
/// continues.
class StartupSplash extends StatefulWidget {
  const StartupSplash({this.onIntroCompleted, super.key});

  static const asset = 'assets/branding/vanta-splash.riv';
  static const artboard = 'Vanta Splash';
  static const stateMachine = 'Splash';
  static const introAnimation = 'Intro';
  static const reducedMotionAnimation = 'Reduced Motion';
  static const completeEvent = 'splash_complete';

  /// The Rive renderer draws the Feather glow; headless tests cannot create it.
  @visibleForTesting
  static rive.Factory Function() riveFactory = () => rive.Factory.rive;

  final VoidCallback? onIntroCompleted;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> {
  rive.File? _file;
  rive.Artboard? _artboard;
  rive.RiveWidgetController? _intro;
  rive.ArtboardPainter? _single;
  bool _loading = false, _completed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) return;
    _loading = true;
    _load(
      widget.onIntroCompleted != null && !MediaQuery.disableAnimationsOf(context),
      DefaultAssetBundle.of(context),
    );
  }

  Future<void> _load(bool animate, AssetBundle bundle) async {
    rive.File? file;
    try {
      file = await rive.File.asset(
        StartupSplash.asset,
        riveFactory: StartupSplash.riveFactory(),
        bundle: bundle,
      );
      if (file == null) throw StateError('Unreadable splash file');
      if (!mounted) {
        file.dispose();
        return;
      }
      final controller = animate ? _IntroController(file, _complete) : null;
      final artboard = animate ? null : file.artboard(StartupSplash.artboard);
      if (!animate && artboard == null) throw StateError('Missing splash artboard');
      setState(() {
        _file = file;
        _intro = controller;
        _artboard = artboard;
        // Reduced motion plays only its fade-in; the held final frame starts
        // at the end of the intro.
        _single = artboard == null
            ? null
            : _SingleAnimationPainter(
                widget.onIntroCompleted == null
                    ? StartupSplash.introAnimation
                    : StartupSplash.reducedMotionAnimation,
                startAtEnd: widget.onIntroCompleted == null,
                onEnd: _complete,
              );
      });
    } catch (_) {
      // Startup must never wait on the decorative intro.
      file?.dispose();
      if (mounted) _complete();
    }
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    // Events and settling are reported while painting; continue afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onIntroCompleted?.call();
    });
  }

  @override
  void dispose() {
    _intro?.dispose();
    _single?.dispose();
    _artboard?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intro = _intro, artboard = _artboard, single = _single;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('startup-splash'),
        backgroundColor: AppColors.launchBackground,
        body: SizedBox.expand(
          child: ExcludeSemantics(
            child: switch ((intro, artboard, single)) {
              (final intro?, _, _) => rive.RiveWidget(controller: intro, fit: rive.Fit.contain),
              (_, final artboard?, final single?) => rive.RiveArtboardWidget(
                artboard: artboard,
                painter: single,
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }
}

/// Runs the `Splash` state machine and reports its `splash_complete` event,
/// or the machine settling at the held last frame if no event arrives.
final class _IntroController extends rive.RiveWidgetController {
  _IntroController(super.file, this.onComplete)
    : super(
        artboardSelector: const rive.ArtboardNamed(StartupSplash.artboard),
        stateMachineSelector: const rive.StateMachineNamed(StartupSplash.stateMachine),
      ) {
    stateMachine.addEventListener(_onEvent);
  }

  final VoidCallback onComplete;

  void _onEvent(rive.Event event) {
    if (event.name == StartupSplash.completeEvent) onComplete();
  }

  @override
  bool advance(double elapsedSeconds) {
    final playing = super.advance(elapsedSeconds);
    if (!playing) onComplete();
    return playing;
  }

  @override
  void dispose() {
    stateMachine.removeEventListener(_onEvent);
    super.dispose();
  }
}

/// Plays one timeline in isolation (never alongside the state machine).
final class _SingleAnimationPainter extends rive.BasicArtboardPainter {
  _SingleAnimationPainter(this.name, {required this.startAtEnd, required this.onEnd})
    : super(fit: rive.Fit.contain);

  final String name;
  final bool startAtEnd;
  final VoidCallback onEnd;
  rive.Animation? _animation;

  @override
  void artboardChanged(rive.Artboard artboard) {
    super.artboardChanged(artboard);
    _animation?.dispose();
    final animation = _animation = artboard.animationNamed(name);
    if (animation != null && startAtEnd) animation.time = animation.duration;
    notifyListeners();
  }

  @override
  bool advance(double elapsedSeconds) {
    final playing = _animation?.advanceAndApply(elapsedSeconds) ?? false;
    if (!playing) onEnd();
    return playing;
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }
}
