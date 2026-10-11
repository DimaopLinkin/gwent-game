import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const uuid = Uuid();

  bool _loading = false;

  String uuid1 = 'Press the button to generate a UUID';

  Future<void> _generateUuidAndCopyToClipboard(BuildContext context) async {
    setState(() {
      _loading = true;
    });
    final newUuid = uuid.v4();
    await Clipboard.setData(ClipboardData(text: newUuid));

    if (context.mounted) {
      showBottomSheet(
        context: context,
        builder: (context) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              Navigator.pop(context);
            }
          });
          return BottomSheet(
            onClosing: () {},
            builder: (context) {
              return Material(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                  child: Text('UUID copied to clipboard: $newUuid'),
                ),
              );
            },
          );
        },
      );
    }

    setState(() {
      uuid1 = newUuid;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text(widget.title)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(mainAxisAlignment: .center, children: [SelectableText(uuid1)]),
          ),
          if (_loading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          return FloatingActionButton(
            onPressed: _loading ? null : () => _generateUuidAndCopyToClipboard(context),
            tooltip: 'Generate',
            child: const Icon(Icons.settings),
          );
        },
      ),
    );
  }
}
