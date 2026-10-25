import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrustCheckApp());
}

class TrustCheckApp extends StatelessWidget {
  const TrustCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TrustCheck AI',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF175CD3),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<RiskResult> _history = [];
  bool _busy = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('risk_history') ?? const [];
    final loaded = <RiskResult>[];
    for (final item in raw) {
      try {
        loaded.add(RiskResult.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {}
    }
    if (mounted) setState(() => _history.addAll(loaded));
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final items = _history
        .take(20)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await prefs.setStringList('risk_history', items);
  }

  Future<void> _clearHistory() async {
    setState(() => _history.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('risk_history');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    setState(() => _busy = true);
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (image == null) return;

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final result = await recognizer.processImage(
          InputImage.fromFilePath(image.path),
        );
        if (!mounted) return;
        _controller.text = result.text;
        if (result.text.trim().isEmpty) {
          _snack(
            'No readable Latin/Roman-Urdu text was found. Urdu-script screenshots may need manual paste in V1.',
          );
        }
      } finally {
        await recognizer.close();
      }
    } catch (_) {
      if (mounted) _snack('The screenshot could not be processed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _check() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _snack('Paste a message or choose a screenshot first.');
      return;
    }
    final result = RiskEngine().analyze(text);
    setState(() => _history.insert(0, result));
    _saveHistory();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 8),
            Text(
              'TrustCheck AI',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _CheckView(
            controller: _controller,
            busy: _busy,
            onPickScreenshot: _pickScreenshot,
            onCheck: _check,
          ),
          HistoryView(history: _history, onClear: _clearHistory),
          const LearnView(),
          const AboutView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Check'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      ),
    );
  }
}

class _CheckView extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onPickScreenshot;
  final VoidCallback onCheck;

  const _CheckView({
    required this.controller,
    required this.busy,
    required this.onPickScreenshot,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Check before you trust.',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a message or scan a screenshot. Get a simple risk result and the safest next step.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Message to check',
              hintText:
                  'Paste an SMS, WhatsApp, job, bank, marketplace or investment message...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : onCheck,
            icon: const Icon(Icons.search),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Check message'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onPickScreenshot,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Scan screenshot'),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.lock_outline, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Private by default: V1 checks only what you paste or select.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final RiskResult result;
  const ResultScreen({super.key, required this.result});

  Color _riskColor(BuildContext context) {
    return switch (result.level) {
      RiskLevel.low => Colors.green.shade700,
      RiskLevel.caution => Colors.amber.shade900,
      RiskLevel.suspicious => Colors.deepOrange.shade700,
      RiskLevel.high => Theme.of(context).colorScheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(context);
    final icon = switch (result.level) {
      RiskLevel.low => Icons.shield_outlined,
      RiskLevel.caution => Icons.info_outline,
      RiskLevel.suspicious => Icons.warning_amber_rounded,
      RiskLevel.high => Icons.gpp_bad_outlined,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Risk analysis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(icon, size: 58, color: color),
                  const SizedBox(height: 10),
                  Text(
                    result.level.label,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${result.score}/100',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.category,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: color.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                result.summary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'What to do now',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          ...result.actions.take(2).map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline, color: color),
              title: Text(a),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.search),
              title: const Text(
                'Why TrustCheck flagged this',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              children: [
                if (result.signals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'No meaningful scam pattern was detected. This is not proof that the sender is legitimate.',
                    ),
                  )
                else
                  ...result.signals.map(
                    (s) => ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        child: Text(
                          '+${s.points}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      title: Text(
                        s.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(s.detail),
                    ),
                  ),
              ],
            ),
          ),
          if (result.actions.length > 2)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text(
                  'More safety steps',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                children: result.actions
                    .skip(2)
                    .map(
                      (a) => ListTile(
                        leading: Icon(Icons.check_circle_outline, color: color),
                        title: Text(a),
                      ),
                    )
                    .toList(),
              ),
            ),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            'TrustCheck provides a risk assessment, not a guarantee that a message is fraudulent or legitimate. New scam methods evolve continuously, so independent verification remains important.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class HistoryView extends StatelessWidget {
  final List<RiskResult> history;
  final VoidCallback onClear;
  const HistoryView({super.key, required this.history, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('No checks yet. Results from this app session will appear here.'),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent checks',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final r = history[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Icon(
                r.level == RiskLevel.high
                    ? Icons.gpp_bad_outlined
                    : r.level == RiskLevel.suspicious
                        ? Icons.warning_amber_rounded
                        : Icons.shield_outlined,
              ),
              title: Text(
                '${r.score}/100 · ${r.level.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${r.category}\n${r.text}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ResultScreen(result: r)),
              ),
            ),
          ),
        );
      },
    ),
        ),
      ],
    );
  }
}

class LearnView extends StatelessWidget {
  const LearnView({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'Harmless-looking first contact',
        'A scam may begin with a simple reply request, vague question or friendly introduction. Verify unknown senders before engaging.'
      ),
      (
        'Unexpected bank alerts',
        'Do not reply to unexpected debit or account alerts. Open the bank’s official app or call a verified number independently.'
      ),
      (
        'OTP, PIN & credential requests',
        'Never send OTPs, PINs, passwords, recovery phrases or private keys to another person.'
      ),
      (
        'Urgency and pressure',
        '“Act now”, “10 minutes left”, “account blocked”, emergency claims and artificial deadlines are common social-engineering tactics.'
      ),
      (
        'Job & task scams',
        'Be cautious with unsolicited recruiters, vague flexible roles, easy daily earnings, prepaid tasks or requests to move to Telegram/WhatsApp groups.'
      ),
      (
        'Investment-group grooming',
        'Fake experts and fake group members may post fabricated profit screenshots to create social proof before asking you to invest.'
      ),
      (
        'Family / colleague impersonation',
        'Unknown numbers claiming to be a relative, boss or friend in an emergency should be verified using a known number.'
      ),
      (
        'Suspicious links & files',
        'Do not open unexpected links, APKs, documents or remote-access tools. Find the official app or site yourself.'
      ),
      (
        'Guaranteed returns',
        'Guaranteed, risk-free or unusually high returns are major investment-fraud indicators.'
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Modern scam warning signs',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scams evolve. TrustCheck looks beyond obvious OTP and payment requests and also considers how a conversation is being initiated.',
        ),
        const SizedBox(height: 12),
        ...items.map(
          (x) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(
                  x.$1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(x.$2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'TrustCheck AI',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        const Text('Version 1.1.0 · Polished V1'),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'TrustCheck identifies common fraud, phishing, impersonation and social-engineering indicators. It also flags uncertain behavioral patterns as Caution or Suspicious instead of treating every unproven message as safe or fraudulent.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Automatic background monitoring is not enabled in V1. Real-time notification protection is planned as a separate permission-aware protection mode.',
            ),
          ),
        ),
      ],
    );
  }
}

enum RiskLevel { low, caution, suspicious, high }

extension RiskLevelLabel on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'LOW RISK',
        RiskLevel.caution => 'CAUTION',
        RiskLevel.suspicious => 'SUSPICIOUS',
        RiskLevel.high => 'HIGH RISK',
      };
}

class RiskSignal {
  final String title;
  final String detail;
  final int points;
  const RiskSignal(this.title, this.detail, this.points);
}

class RiskResult {
  final String text;
  final int score;
  final RiskLevel level;
  final String category;
  final String summary;
  final List<RiskSignal> signals;
  final List<String> actions;

  const RiskResult({
    required this.text,
    required this.score,
    required this.level,
    required this.category,
    required this.summary,
    required this.signals,
    required this.actions,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'score': score,
        'level': level.name,
        'category': category,
        'summary': summary,
        'signals': signals
            .map((s) => {
                  'title': s.title,
                  'detail': s.detail,
                  'points': s.points,
                })
            .toList(),
        'actions': actions,
      };

  factory RiskResult.fromJson(Map<String, dynamic> json) {
    return RiskResult(
      text: json['text'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      level: RiskLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => RiskLevel.low,
      ),
      category: json['category'] as String? ?? 'No specific scam pattern identified',
      summary: json['summary'] as String? ?? '',
      signals: ((json['signals'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => RiskSignal(
              e['title'] as String? ?? '',
              e['detail'] as String? ?? '',
              e['points'] as int? ?? 0,
            ),
          )
          .toList(),
      actions: ((json['actions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class _Rule {
  final RegExp regex;
  final String title;
  final String detail;
  final int points;
  const _Rule(this.regex, this.title, this.detail, this.points);
}

class RiskEngine {
  static final RegExp _url = RegExp(
    r'((https?:\/\/|www\.)[^\s]+|(?:[a-z0-9-]+\.)+(?:com|net|org|pk|in|xyz|top|click|info|live|site|app)\b[^\s]*)',
    caseSensitive: false,
  );

  static final RegExp _phone = RegExp(
    r'(?:\+\d{1,3}[\s-]?)?(?:\d[\s-]?){9,13}',
  );

  final List<_Rule> hardRules = [
    _Rule(
      RegExp(r'\b(otp|one[ -]?time password|verification code|pin|password)\b', caseSensitive: false),
      'Requests a security credential',
      'Legitimate services should not ask you to send an OTP, PIN or password to another person.',
      30,
    ),
    _Rule(
      RegExp(r'\b(seed phrase|recovery phrase|private key|wallet key)\b', caseSensitive: false),
      'Requests crypto credentials',
      'A legitimate service should never ask for your wallet seed phrase or private key.',
      40,
    ),
    _Rule(
      RegExp(r'\b(anydesk|teamviewer|remote access|screen share|install this app|install apk|apk file)\b', caseSensitive: false),
      'Requests device access or installation',
      'Remote-access tools and unexpected app files can give an attacker control of your device.',
      30,
    ),
    _Rule(
      RegExp(r'\b(send|transfer|pay|deposit|top[ -]?up|recharge|bhejo|bhejein|jama)\b.{0,50}\b(money|cash|fee|payment|rs\.?|pkr|usd|usdt|paisa|rupees|upi)\b', caseSensitive: false),
      'Requests money or a deposit',
      'Unexpected payment, deposit or transfer requests materially increase fraud risk.',
      25,
    ),
    _Rule(
      RegExp(r'\b(guaranteed|double|2x|100% profit|risk[ -]?free|fixed profit|double paisa|paisa double|guaranteed return)\b', caseSensitive: false),
      'Unrealistic return claim',
      'Guaranteed or unusually high financial returns are a major investment-scam indicator.',
      28,
    ),
    _Rule(
      RegExp(r'\b(prize|winner|lottery|gift|reward|congratulations|inaam|انعام|لاٹری)\b', caseSensitive: false),
      'Unexpected reward',
      'Unexpected prizes and rewards are frequently used as scam bait.',
      18,
    ),
    _Rule(
      RegExp(r'(او ٹی پی|پاس ورڈ|پن کوڈ|رقم بھیج|پیسے بھیج|اکاؤنٹ بند|اکاؤنٹ بلاک)'),
      'Urdu high-risk phrase',
      'The message contains a common Urdu-language scam indicator.',
      24,
    ),
  ];

  final List<_Rule> contextRules = [
    _Rule(
      RegExp(r'\b(urgent|immediately|act now|within \d+ minutes?|today only|last chance|foran|forun|jaldi|abhi|فوری|فوراً|جلدی)\b', caseSensitive: false),
      'Creates urgency or pressure',
      'Artificial urgency can push people to act before independently verifying the request.',
      12,
    ),
    _Rule(
      RegExp(r'(account.{0,24}(blocked|suspended|closed|frozen)|verify.{0,20}account|اکاؤنٹ.{0,24}(بند|بلاک))', caseSensitive: false),
      'Threatens account restriction',
      'Fear of account loss is a common social-engineering technique.',
      18,
    ),
    _Rule(
      RegExp(r'\b(bank|easypaisa|jazzcash|paypal|daraz|courier|police|government|nadra|fia|fbr|sebi|broker|exchange)\b', caseSensitive: false),
      'Claims an institutional identity',
      'Unexpected institutional messages should be verified through an independently found official channel.',
      8,
    ),
    _Rule(
      RegExp(r'\b(job|recruitment|recruiter|hiring|vacancy|work from home|flexible role|part[ -]?time|online task|task job|daily earning|easy income)\b', caseSensitive: false),
      'Unsolicited recruitment / earning theme',
      'Vague or unexpected job approaches are commonly used to start task and recruitment scams.',
      14,
    ),
    _Rule(
      RegExp(r'\b(stock tip|stock recommendation|trading group|investment group|vip group|whatsapp group|telegram group|crypto signal|forex signal)\b', caseSensitive: false),
      'Investment-group solicitation',
      'Fraudulent groups may use fake experts and fabricated profit claims to build trust.',
      18,
    ),
    _Rule(
      RegExp(r'\b(son|daughter|mother|father|brother|sister|friend|boss|colleague|relative)\b.{0,45}\b(emergency|urgent|lost my phone|new number|need money|send money|loan)\b', caseSensitive: false),
      'Possible family or colleague impersonation',
      'Emergency claims from a new or unknown number should be verified using a known contact method.',
      24,
    ),
    _Rule(
      RegExp(r'\b(debited|debit alert|transaction alert|transaction of|withdrawal|purchase of|charged|payment of)\b', caseSensitive: false),
      'Unexpected financial alert',
      'Unexpected transaction alerts can be used to trigger panic and steer users into a fraudulent interaction.',
      16,
    ),
    _Rule(
      RegExp(r'\b(reply|respond|type|send)\s+(yes|no|y|n|stop|1|2)\b|\breply\s+(yes|no)\b', caseSensitive: false),
      'Engagement / reply request',
      'A harmless-looking reply can be used to continue social engineering. Verify the sender before engaging.',
      14,
    ),
    _Rule(
      RegExp(r'\b(may i share|can i share|are you interested|would you be interested|kindly reply|reply back|message me back|contact me)\b', caseSensitive: false),
      'Conversation hook from an unknown sender',
      'Scams can begin with low-pressure engagement before any money, link or credential request appears.',
      10,
    ),
    _Rule(
      RegExp(r'\b(join|move to|contact on|message on)\b.{0,25}\b(whatsapp|telegram)\b', caseSensitive: false),
      'Moves conversation to another platform',
      'Moving a conversation to a private messaging group can reduce oversight and increase manipulation risk.',
      10,
    ),
    _Rule(
      RegExp(r'\b(cnic|aadhaar|passport|id card|identity card|date of birth|dob|bank account|account number)\b', caseSensitive: false),
      'Requests identity or account information',
      'Identity and financial details should only be shared after independently verifying the recipient and purpose.',
      20,
    ),
    _Rule(
      RegExp(r'\b(profit screenshot|proof of profit|members earning|successful withdrawal|withdrawal proof|testimonial)\b', caseSensitive: false),
      'Social-proof / profit grooming',
      'Fake testimonials and profit screenshots are commonly used to create false legitimacy.',
      15,
    ),
  ];

  RiskResult analyze(String input) {
    final text = input.trim();
    final lower = text.toLowerCase();
    var score = 0;
    final signals = <RiskSignal>[];

    void addSignal(RiskSignal signal) {
      if (signals.any((s) => s.title == signal.title)) return;
      score += signal.points;
      signals.add(signal);
    }

    for (final rule in [...hardRules, ...contextRules]) {
      if (rule.regex.hasMatch(text)) {
        addSignal(RiskSignal(rule.title, rule.detail, rule.points));
      }
    }

    final links = _url.allMatches(text).toList();
    if (links.isNotEmpty) {
      final risky = lower.contains('bit.ly') ||
          lower.contains('tinyurl') ||
          lower.contains('.xyz') ||
          lower.contains('.top') ||
          lower.contains('.click') ||
          lower.contains('t.me/') ||
          lower.contains('wa.me/');
      final pts = risky ? 24 : 12;
      addSignal(
        RiskSignal(
          'Contains a link',
          risky
              ? 'The message contains a shortened, messaging-platform or unusually risky-looking link.'
              : 'Verify the exact domain independently before opening it.',
          pts,
        ),
      );
    }

    final hasInternationalNumber =
        text.contains('+') && _phone.hasMatch(text);
    if (hasInternationalNumber &&
        RegExp(
          r'\b(job|recruit|investment|bank|reply|interested)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      addSignal(
        const RiskSignal(
          'Unknown international contact context',
          'Unexpected cross-border contact combined with recruitment, finance or engagement language deserves extra verification.',
          8,
        ),
      );
    }

    final hasRecruitment = RegExp(
      r'\b(job|recruitment|recruiter|hiring|vacancy|flexible role|part[ -]?time|work from home|online task)\b',
      caseSensitive: false,
    ).hasMatch(text);

    if (hasRecruitment &&
        RegExp(
          r'\b(flexible role|are you interested|would you be interested|may i share|can i share|part[ -]?time)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      addSignal(
        const RiskSignal(
          'Vague recruitment approach',
          'The sender does not provide enough verifiable job detail before asking you to engage.',
          10,
        ),
      );
    }

    final bankAlert = RegExp(
      r'\b(bank|account|card|transaction|debited|withdrawal|payment)\b',
      caseSensitive: false,
    ).hasMatch(text);

    final replyHook = RegExp(
      r'\b(reply|respond|type|send)\s+(yes|no|y|n|stop|1|2)\b',
      caseSensitive: false,
    ).hasMatch(text);

    if (bankAlert && replyHook) {
      addSignal(
        const RiskSignal(
          'Financial alert asks you to engage',
          'Do not reply directly to an unexpected financial alert. Check the official banking app or verified support channel instead.',
          18,
        ),
      );
    }

    final investmentTheme = RegExp(
      r'\b(stock|share market|trading|investment|crypto|forex|profit|returns?)\b',
      caseSensitive: false,
    ).hasMatch(text);

    final groupTheme = RegExp(
      r'\b(group|whatsapp|telegram|vip|expert|mentor|analyst)\b',
      caseSensitive: false,
    ).hasMatch(text);

    if (investmentTheme && groupTheme) {
      addSignal(
        const RiskSignal(
          'Investment grooming pattern',
          'Investment scams often begin with education, tips or community groups before requesting funds or directing users to a fake platform.',
          16,
        ),
      );
    }

    if (RegExp(
      r'\b(sale|offer|discount|promotion|deal|buy now|sell your|best price)\b',
      caseSensitive: false,
    ).hasMatch(text) &&
        signals.isEmpty) {
      addSignal(
        const RiskSignal(
          'Unsolicited promotional message',
          'This looks commercial rather than fraudulent, but unsolicited contact should still be treated cautiously.',
          5,
        ),
      );
    }

    score = score.clamp(0, 100);

    final level = score >= 75
        ? RiskLevel.high
        : score >= 45
            ? RiskLevel.suspicious
            : score >= 15
                ? RiskLevel.caution
                : RiskLevel.low;

    final category = _categoryFor(
      text,
      links.isNotEmpty,
      signals,
    );

    final summary = switch (level) {
      RiskLevel.high =>
        'Strong or multiple scam indicators are present. Avoid engaging or acting on the message until it has been independently verified.',
      RiskLevel.suspicious =>
        'Several suspicious behavioral or content signals are present. Avoid replying, clicking or paying until the sender and request are independently verified.',
      RiskLevel.caution =>
        'The message is not clearly fraudulent, but it contains patterns that justify caution. Verify the sender before replying or continuing the conversation.',
      RiskLevel.low =>
        'No meaningful scam pattern was detected in the supplied text. Stay alert because new scams can begin with harmless-looking contact.',
    };

    final actions = _actionsFor(
      level,
      links.isNotEmpty,
      bankAlert,
      hasRecruitment,
      investmentTheme,
      signals,
    );

    return RiskResult(
      text: text,
      score: score,
      level: level,
      category: category,
      summary: summary,
      signals: signals,
      actions: actions,
    );
  }

  String _categoryFor(
    String text,
    bool hasLink,
    List<RiskSignal> signals,
  ) {
    if (RegExp(r'\b(seed phrase|private key|wallet|usdt|crypto)\b', caseSensitive: false).hasMatch(text)) {
      return 'Crypto / investment risk';
    }
    if (RegExp(r'\b(job|recruitment|recruiter|hiring|vacancy|work from home|flexible role|online task)\b', caseSensitive: false).hasMatch(text)) {
      return 'Recruitment / job-contact risk';
    }
    if (RegExp(r'\b(stock|trading|investment|forex|guaranteed return)\b', caseSensitive: false).hasMatch(text)) {
      return 'Investment / trading solicitation';
    }
    if (RegExp(r'\b(bank|easypaisa|jazzcash|paypal|account|debited|transaction|otp)\b', caseSensitive: false).hasMatch(text)) {
      return 'Financial impersonation / phishing risk';
    }
    if (signals.any((s) => s.title.contains('family') || s.title.contains('colleague'))) {
      return 'Impersonation / emergency request';
    }
    if (signals.any((s) => s.title.contains('Engagement') || s.title.contains('Conversation hook'))) {
      return 'Suspicious engagement request';
    }
    if (hasLink) return 'Link / phishing risk';
    if (signals.isNotEmpty) return 'Social-engineering / contextual risk';
    return 'No specific scam pattern identified';
  }

  List<String> _actionsFor(
    RiskLevel level,
    bool hasLink,
    bool bankAlert,
    bool recruitment,
    bool investment,
    List<RiskSignal> signals,
  ) {
    final actions = <String>[];
    final hasEngagementSignal = signals.any(
      (s) =>
          s.title.contains('Engagement') ||
          s.title.contains('Conversation hook') ||
          s.title.contains('Vague recruitment'),
    );

    if (level != RiskLevel.low || hasEngagementSignal) {
      actions.add(
        'Avoid replying until you independently verify who the sender is and why they contacted you.',
      );
    }
    if (bankAlert) {
      actions.add(
        'For bank or transaction alerts, open the official banking app or call a verified number yourself. Do not use contact details supplied by the message.',
      );
    }
    if (hasLink) {
      actions.add(
        'Do not open the message link until the domain and sender have been independently verified.',
      );
    }
    if (recruitment) {
      actions.add(
        'Verify the recruiter, employer, vacancy and official company contact details before sharing documents or continuing.',
      );
    }
    if (investment) {
      actions.add(
        'Do not rely on group testimonials, profit screenshots or guaranteed-return claims. Verify the platform and regulator independently.',
      );
    }
    if (level == RiskLevel.suspicious || level == RiskLevel.high) {
      actions.add(
        'Do not send money, OTPs, PINs, passwords, identity documents, recovery phrases or remote-access permissions.',
      );
    }
    actions.add(
      'If the claim involves a person you know, contact them through a previously saved number or another trusted channel.',
    );

    return actions.toSet().toList();
  }
}
