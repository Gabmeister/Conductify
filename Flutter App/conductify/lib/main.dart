import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';

List<CameraDescription>? cameras;
Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title:'Conductify',
      theme:ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          background: Colors.grey[850]!,
        ),
        scaffoldBackgroundColor: Colors.grey[850],
        useMaterial3: true,
      ),
      home:WelcomeScreen(cameras:cameras),
    );
  }
}

class WelcomeScreen extends StatefulWidget{
  final List<CameraDescription>? cameras;
  const WelcomeScreen({Key?key,this.cameras}):super(key: key);
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>{
  final storage = FlutterSecureStorage();

  Future<void> authenticateUser() async{
    // create uri object with flask api route 
    final Uri url = Uri.parse('https://conductify-fypfinal-c6dc46d84d06.herokuapp.com/login');
    if (await canLaunchUrl(url)){
      await launchUrl(url);
    }else{
      throw 'Could not launch $url';
    }
  }

  void initUniLinksListener() async{
  linkStream.listen((String? link) async{
    if (link != null){
      var uri = Uri.parse(link);
      // extract spotify auth code
      var code = uri.queryParameters['code'];
      if (code != null) {
        print("Received authorization code: $code"); // log for debug
        await exchangeToken(code); // exchange auth code for auth token 
      }
    }
  }, onError:(err){
    // debug err catch
    print("Failed to get auth code: $err");
  });
  }

  Future<void> exchangeToken(String authCode) async{
    final Uri url = Uri.parse('https://conductify-fypfinal-c6dc46d84d06.herokuapp.com/exchange_token');
    final response = await http.post(
      url,
      headers: {
        'Content-Type':'application/json',
      },
      body: jsonEncode({'code': authCode}),
    );

    // handle response
    if (response.statusCode == 200){
      final responseData = jsonDecode(response.body);
      final accessToken = responseData['access_token'];
      final refreshToken = responseData['refresh_token'];
      print("Access token and refresh token received successfully.");
      print("Access token:\n$accessToken");
      // store access,refresh tokens with flutter storage
      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);
    } else {
      // err response log debug
      print("Failed to exchange authorization code for tokens: ${response.body}");
    }
  }

  @override
  void initState(){
    super.initState();
    initUniLinksListener(); // listen for unilinks
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Conductify: A Spotify Controller',
          style: TextStyle(color: Colors.white),
          ),
        backgroundColor: Colors.grey[850],
        ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Image.asset('assets/conductify_logo.png'),
            ),
            ElevatedButton( //elevated button for spotify auth
              onPressed:() async{
                await authenticateUser();
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[800],
              ),
              child: const Text('Authenticate with Spotify'),
            ),
            ElevatedButton( //elevated button for live image capture
              onPressed:(){
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => CameraScreen(cameras: widget.cameras),
                ));
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[800],
              ),
              child: const Text('Start Image Capture'),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget{
  final List<CameraDescription>? cameras;
  const CameraScreen({super.key, this.cameras});
  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen>{
  CameraController? controller;
  Timer? _timer;
  bool isCapturing = false;
  int countdownValue = 3;
  String predictionText = '';
  final storage = FlutterSecureStorage();

  @override
  void initState(){ // initialize camera screen camera + countdown
    super.initState();
    initializeCamera();
    startCountdown();
  }

  Future<void> initializeCamera()async {
    if (widget.cameras != null && widget.cameras!.isNotEmpty) {
      final CameraDescription frontCamera = widget.cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front, // use front selfie cam
        orElse:() => widget.cameras!.first,
      );

      controller = CameraController(frontCamera, ResolutionPreset.medium);
      await controller!.initialize();
      if (!mounted) return;
      setState((){});
    }
  }

  void startCountdown() {
    _timer = Timer.periodic(Duration(seconds: 1),(Timer timer){
      if (countdownValue > 0){
        setState(() {
          countdownValue--;
        });
      }else{
        captureImage();
        setState((){
          countdownValue = 3; // reset counter to 3
        });
      }
    });
  }

  Future<void> captureImage()async {
    if (controller != null && controller!.value.isInitialized) {
      isCapturing = true;
      try{
        final XFile file = await controller!.takePicture(); // read img as xfile
        final bytes = await file.readAsBytes(); // read file as bytes
        await uploadImage(bytes, file.name); // send bytes to uploadimage()
      } catch(e){ 
        print('Error taking picture: $e');
      } finally{
        isCapturing = false;
      }
    }
  }

  Future<void> uploadImage(Uint8List bytes, String fileName)async {
    var uri = Uri.parse('https://conductify-fypfinal-c6dc46d84d06.herokuapp.com/predict'); // prediction route
    var request = http.MultipartRequest('POST', uri); // ensure HTTP POST req type
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: fileName,
      contentType: MediaType('image', 'jpeg'),
    ));
    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['prediction'] != null) {
        setState(() {
          predictionText = responseData['prediction'];
        });
        controlMusic(responseData['prediction']);
      }
    } catch (e) {
      print('Error sending image: $e');
    }
  }

  Future<void> controlMusic(String command)async {
    final accessToken = await storage.read(key:'accessToken'); // get access token from flutter storage
    if (accessToken == null){ // handle err log debug
      print("No access token available");
      return;
    }
    switch (command){ // switch for handling gesture output
      case 'play':
        await performSpotifyAction(accessToken, 'https://api.spotify.com/v1/me/player/play', isPost: false);
        break;
      case 'pause':
        await performSpotifyAction(accessToken, 'https://api.spotify.com/v1/me/player/pause', isPost: false);
        break;
      case 'nextsong':
        await performSpotifyAction(accessToken, 'https://api.spotify.com/v1/me/player/next', isPost: true);
        break;
      case 'prevsong':
        await performSpotifyAction(accessToken, 'https://api.spotify.com/v1/me/player/previous', isPost: true);
        break; 
      case 'volumedown': // fallthrough, same logic for both vol up and down 
      case 'volumeup':
        await adjustVolume(accessToken, command);
        break;
      default:
        print("Invalid command: $command");
    }
  }
  // function to adjust spotify volume based on 'volumeup' or 'volumedown'
  Future<void> adjustVolume(String accessToken, String command)async {
    // adjust vol by 20% increments
    const volumeAdjustment = 20;
    int currentVolume = await getCurrentVolume(accessToken); // get current volume
    // calculate new volume based on command
    int newVolume = command == 'volumeup' ? min(currentVolume + volumeAdjustment, 100) : max(currentVolume - volumeAdjustment, 0);
    await setVolume(accessToken, newVolume); // set new volume using above calculation
  }

  Future<void> setVolume(String accessToken, int volume)async { // this function sets volume to a specific value
    final response = await http.put( // make PUT req. to spotify
      Uri.parse('https://api.spotify.com/v1/me/player/volume?volume_percent=$volume'),
      headers: { // prepare header with token
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 204){ // error checking
      print("Volume set to $volume successfully."); 
    } else {
      print("Failed to set volume: ${response.body}");
    }
  }

  Future<int> getCurrentVolume(String accessToken)async { // fetch current volume 
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/player'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200){
      final responseData = jsonDecode(response.body);
      return responseData['device']['volume_percent'] ?? 50; // default 50 upon err
    } else {
      print("Failed to retrieve current volume: ${response.body}");
      return 50; // default 50 on err
    }
  }
  // function to perform spotify music action
  Future<void> performSpotifyAction(String accessToken, String url, {bool isPost = true})async {
    final response = isPost ? await http.post( // if isPost boolean = true
      Uri.parse(url),
      headers: {
        'Authorization':'Bearer $accessToken',
      },
    ) : await http.put( // if isPost boolean = false
      Uri.parse(url),
      headers: {
        'Authorization':'Bearer $accessToken',
      },
    );
    if (response.statusCode == 204) { // error checking
      print("Action performed successfully");
    } else {
      print("Failed to perform action: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar( // top app bar
        title: const Text(
          'Conduct and Enjoy!',
          style: TextStyle(color: Colors.white), //title style
          ),
        backgroundColor: Colors.grey[850],
        ),
      body: Stack( // define scaffold body
        children: [
          controller != null && controller!.value.isInitialized
              ? CameraPreview(controller!)
              : const Center(child: CircularProgressIndicator()), 
          // overlay UI components on top of camera view
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: Text(
                    predictionText, // display gesture label
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Spacer(),
              Center( // center countdown timer
                child: Text(
                  countdownValue > 0 ? '$countdownValue' : '', //display countdown
                  style: TextStyle(fontSize:48, fontWeight:FontWeight.bold, color:Colors.white), 
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  @override
  void dispose(){
    controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }
}