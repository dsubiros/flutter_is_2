import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isBusy = false;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  String? _codeVerifier;
  String? _nonce;
  String? _authorizationCode;
  String? _refreshToken;
  String? _accessToken;
  String? _idToken;

  final TextEditingController _authorizationCodeTextController =
  TextEditingController();
  final TextEditingController _accessTokenTextController =
  TextEditingController();
  final TextEditingController _accessTokenExpirationTextController =
  TextEditingController();

  final TextEditingController _idTokenTextController = TextEditingController();
  final TextEditingController _refreshTokenTextController =
  TextEditingController();
  String? _userInfo;

  // For a list of client IDs, go to https://demo.duendesoftware.com
  final String _clientId = 'interactive.public';
  final String _redirectUrl = 'com.duendesoftware.demo:/oauthredirect';
  final String _issuer = 'https://demo.duendesoftware.com';
  final String _discoveryUrl =
      'https://demo.duendesoftware.com/.well-known/openid-configuration';
  final String _postLogoutRedirectUrl = 'com.duendesoftware.demo:/';
  final List<String> _scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
    'api'
  ];

  final AuthorizationServiceConfiguration _serviceConfiguration =
  const AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://demo.duendesoftware.com/connect/authorize',
    tokenEndpoint: 'https://demo.duendesoftware.com/connect/token',
    endSessionEndpoint: 'https://demo.duendesoftware.com/connect/endsession',
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Visibility(
                  visible: _isBusy,
                  child: const LinearProgressIndicator(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  child: const Text('Sign in with no code exchange'),
                  onPressed: () => _signInWithNoCodeExchange(),
                ),
                ElevatedButton(
                  child: const Text(
                      'Sign in with no code exchange and generated nonce'),
                  onPressed: () => _signInWithNoCodeExchangeAndGeneratedNonce(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  child: const Text('Exchange code'),
                  onPressed: _authorizationCode != null ? _exchangeCode : null,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  child: const Text('Sign in with auto code exchange'),
                  onPressed: () => _signInWithAutoCodeExchange(),
                ),
                if (Platform.isIOS || Platform.isMacOS)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      child: const Text(
                        'Sign in with auto code exchange using ephemeral session',
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () => _signInWithAutoCodeExchange(
                          preferEphemeralSession: true),
                    ),
                  ),
                ElevatedButton(
                  child: const Text('Refresh token'),
                  onPressed: _refreshToken != null ? _refresh : null,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  child: const Text('End session'),
                  onPressed: _idToken != null
                      ? () async {
                    await _endSession();
                  }
                      : null,
                ),
                const SizedBox(height: 8),
                const Text('authorization code'),
                TextField(
                  controller: _authorizationCodeTextController,
                ),
                const Text('access token'),
                TextField(
                  controller: _accessTokenTextController,
                ),
                const Text('access token expiration'),
                TextField(
                  controller: _accessTokenExpirationTextController,
                ),
                const Text('id token'),
                TextField(
                  controller: _idTokenTextController,
                ),
                const Text('refresh token'),
                TextField(
                  controller: _refreshTokenTextController,
                ),
                const Text('test api results'),
                Text(_userInfo ?? ''),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _endSession() async {
    try {
      _setBusyState();
      await _appAuth.endSession(EndSessionRequest(
          idTokenHint: _idToken,
          postLogoutRedirectUrl: _postLogoutRedirectUrl,
          serviceConfiguration: _serviceConfiguration));
      _clearSessionInfo();
    } catch (_) {}
    _clearBusyState();
  }

  void _clearSessionInfo() {
    setState(() {
      _codeVerifier = null;
      _nonce = null;
      _authorizationCode = null;
      _authorizationCodeTextController.clear();
      _accessToken = null;
      _accessTokenTextController.clear();
      _idToken = null;
      _idTokenTextController.clear();
      _refreshToken = null;
      _refreshTokenTextController.clear();
      _accessTokenExpirationTextController.clear();
      _userInfo = null;
    });
  }

  Future<void> _refresh() async {
    try {
      _setBusyState();
      final TokenResponse? result = await _appAuth.token(TokenRequest(
          _clientId, _redirectUrl,
          refreshToken: _refreshToken, issuer: _issuer, scopes: _scopes));
      _processTokenResponse(result);
      await _testApi(result);
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _exchangeCode() async {
    try {
      _setBusyState();
      final TokenResponse? result = await _appAuth.token(TokenRequest(
          _clientId, _redirectUrl,
          authorizationCode: _authorizationCode,
          discoveryUrl: _discoveryUrl,
          codeVerifier: _codeVerifier,
          nonce: _nonce,
          scopes: _scopes));
      _processTokenResponse(result);
      await _testApi(result);
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithNoCodeExchange() async {
    try {
      _setBusyState();
      // use the discovery endpoint to find the configuration
      final AuthorizationResponse? result = await _appAuth.authorize(
        AuthorizationRequest(_clientId, _redirectUrl,
            discoveryUrl: _discoveryUrl, scopes: _scopes, loginHint: 'bob'),
      );

      // or just use the issuer
      // var result = await _appAuth.authorize(
      //   AuthorizationRequest(
      //     _clientId,
      //     _redirectUrl,
      //     issuer: _issuer,
      //     scopes: _scopes,
      //   ),
      // );
      if (result != null) {
        _processAuthResponse(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithNoCodeExchangeAndGeneratedNonce() async {
    try {
      _setBusyState();
      final Random random = Random.secure();
      final String nonce =
      base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
      // use the discovery endpoint to find the configuration
      final AuthorizationResponse? result = await _appAuth.authorize(
        AuthorizationRequest(_clientId, _redirectUrl,
            discoveryUrl: _discoveryUrl,
            scopes: _scopes,
            loginHint: 'bob',
            nonce: nonce),
      );

      if (result != null) {
        _processAuthResponse(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithAutoCodeExchange(
      {bool preferEphemeralSession = false}) async {
    try {
      _setBusyState();

      // show that we can also explicitly specify the endpoints rather than getting from the details from the discovery document
      final AuthorizationTokenResponse? result =
      await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          serviceConfiguration: _serviceConfiguration,
          scopes: _scopes,
          preferEphemeralSession: preferEphemeralSession,
        ),
      );

      // this code block demonstrates passing in values for the prompt parameter. in this case it prompts the user login even if they have already signed in. the list of supported values depends on the identity provider
      // final AuthorizationTokenResponse result = await _appAuth.authorizeAndExchangeCode(
      //   AuthorizationTokenRequest(_clientId, _redirectUrl,
      //       serviceConfiguration: _serviceConfiguration,
      //       scopes: _scopes,
      //       promptValues: ['login']),
      // );

      if (result != null) {
        _processAuthTokenResponse(result);
        await _testApi(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  void _clearBusyState() {
    setState(() {
      _isBusy = false;
    });
  }

  void _setBusyState() {
    setState(() {
      _isBusy = true;
    });
  }

  void _processAuthTokenResponse(AuthorizationTokenResponse response) {
    setState(() {
      _accessToken = _accessTokenTextController.text = response.accessToken!;
      _idToken = _idTokenTextController.text = response.idToken!;
      _refreshToken = _refreshTokenTextController.text = response.refreshToken!;
      _accessTokenExpirationTextController.text =
          response.accessTokenExpirationDateTime!.toIso8601String();
    });
  }

  void _processAuthResponse(AuthorizationResponse response) {
    setState(() {
      // save the code verifier and nonce as it must be used when exchanging the token
      _codeVerifier = response.codeVerifier;
      _nonce = response.nonce;
      _authorizationCode =
          _authorizationCodeTextController.text = response.authorizationCode!;
      _isBusy = false;
    });
  }

  void _processTokenResponse(TokenResponse? response) {
    setState(() {
      _accessToken = _accessTokenTextController.text = response!.accessToken!;
      _idToken = _idTokenTextController.text = response.idToken!;
      _refreshToken = _refreshTokenTextController.text = response.refreshToken!;
      _accessTokenExpirationTextController.text =
          response.accessTokenExpirationDateTime!.toIso8601String();
    });
  }

  Future<void> _testApi(TokenResponse? response) async {
    final http.Response httpResponse = await http.get(
        Uri.parse('https://demo.duendesoftware.com/api/test'),
        headers: <String, String>{'Authorization': 'Bearer $_accessToken'});
    setState(() {
      _userInfo = httpResponse.statusCode == 200 ? httpResponse.body : '';
      _isBusy = false;
    });
  }
}


// import 'package:flutter/material.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // Try running your application with "flutter run". You'll see the
//         // application has a blue toolbar. Then, without quitting the app, try
//         // changing the primarySwatch below to Colors.green and then invoke
//         // "hot reload" (press "r" in the console where you ran "flutter run",
//         // or simply save your changes to "hot reload" in a Flutter IDE).
//         // Notice that the counter didn't reset back to zero; the application
//         // is not restarted.
//         primarySwatch: Colors.blue,
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});
//
//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.
//
//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".
//
//   final String title;
//
//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;
//
//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Invoke "debug painting" (press "p" in the console, choose the
//           // "Toggle Debug Paint" action from the Flutter Inspector in Android
//           // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
//           // to see the wireframe for each widget.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text(
//               'You have pushed the button this many times:',
//             ),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }
