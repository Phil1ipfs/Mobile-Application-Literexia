// lib/helpers/rive_controller.dart
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class RiveAnimationControllerHelper {
  // Singleton class for managing Rive animation controllers
  static final RiveAnimationControllerHelper _instance =
      RiveAnimationControllerHelper._internal();

  factory RiveAnimationControllerHelper() {
    return _instance;
  }

  RiveAnimationControllerHelper._internal();

  Artboard? _riveArtboard;

  // Animation controllers for the penguin
  late RiveAnimationController _controllerIdle;
  late RiveAnimationController _controllerHandsUp;
  late RiveAnimationController _controllerHandsUpShow;
  late RiveAnimationController _controllerHandsDown;
  late RiveAnimationController _controllerSuccess;
  late RiveAnimationController _controllerFail;

  Artboard? get riveArtboard => _riveArtboard;

  // Add a specific controller and remove all others
  void addController(RiveAnimationController controller) {
    removeAllControllers();
    _riveArtboard?.addController(controller);
  }

  // Helper methods to add specific animations
  void addIdleController() => addController(_controllerIdle);
  void addHandsUpController() => addController(_controllerHandsUp);
  void addHandsUpShowController() => addController(_controllerHandsUpShow);
  void addHandsDownController() => addController(_controllerHandsDown);
  void addSuccessController() => addController(_controllerSuccess);
  void addFailController() => addController(_controllerFail);

  // Load the Rive file and initialize controllers
  Future<void> loadRiveFile(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final file = RiveFile.import(data);
      _riveArtboard = file.mainArtboard;

      // Initialize animation controllers based on animation names in the Rive file
      _controllerIdle = SimpleAnimation('idle');
      _controllerHandsUp = SimpleAnimation('hands_up');
      _controllerHandsUpShow = SimpleAnimation('hands_up_show');
      _controllerHandsDown = SimpleAnimation('hands_down');
      _controllerSuccess = SimpleAnimation('success');
      _controllerFail = SimpleAnimation('fail');

      // Start with idle animation
      _riveArtboard?.addController(_controllerIdle);

      print('[Rive] Animation loaded successfully with idle animation');
    } catch (e) {
      print('[Rive] Error loading animation: $e');
    }
  }

  // Remove all controllers
  void removeAllControllers() {
    if (_riveArtboard != null) {
      final listOfControllers = [
        _controllerIdle,
        _controllerHandsUp,
        _controllerHandsUpShow,
        _controllerHandsDown,
        _controllerSuccess,
        _controllerFail,
      ];

      for (var controller in listOfControllers) {
        _riveArtboard!.removeController(controller);
      }
    }
  }

  // Clean up resources
  void dispose() {
    removeAllControllers();
    _controllerIdle.dispose();
    _controllerHandsUp.dispose();
    _controllerHandsUpShow.dispose();
    _controllerHandsDown.dispose();
    _controllerSuccess.dispose();
    _controllerFail.dispose();
  }
}
