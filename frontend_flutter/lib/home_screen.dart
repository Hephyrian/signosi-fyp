import 'package:flutter/material.dart';
import 'screens/speech_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/profile_screen.dart';
import 'dart:async';
import 'widgets/app_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _logoTapCount = 0;
  final int _requiredTapsForDebug = 5;
  late AnimationController _fabAnimationController;
  int _currentEmergencyPage = 1;
  final int _totalEmergencyPages = 3;
  
  // Emergency page titles
  final List<String> _emergencyPageTitles = [
    "Medical",
    "Daily Needs",
    "Communication"
  ];
  
  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }
  
  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }
  
  void _handleLogoTap() {
    setState(() {
      _logoTapCount++;
    });
    
    if (_logoTapCount >= _requiredTapsForDebug) {
      // Reset count and navigate to debug screen
      _logoTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DebugScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppNavigationBar(activeScreen: 'home'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background.withOpacity(0.9),
              Theme.of(context).colorScheme.surface,
            ],
            stops: const [0.0, 0.7],
          ),
          image: DecorationImage(
            image: const AssetImage('assets/images/subtle_pattern.png'),
            fit: BoxFit.cover,
            opacity: 0.04,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              BlendMode.srcOver,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 16.0),
            child: ListView(
              children: [
                _buildWelcomeHeader(context),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Recently Used'),
                const SizedBox(height: 16),
                _buildHorizontalPhraseList(context, recentlyUsedPhrases),
                const SizedBox(height: 36),
                _buildSectionTitle(context, 'Saved'),
                const SizedBox(height: 16),
                _buildHorizontalPhraseList(context, savedPhrases),
                const SizedBox(height: 36),
                _buildSectionTitle(context, 'Emergency Phrases'),
                const SizedBox(height: 16),
                _buildEmergencyPhrasesGrid(context, emergencyPhrases),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: MouseRegion(
        onEnter: (_) => _fabAnimationController.forward(),
        onExit: (_) => _fabAnimationController.reverse(),
        child: Container(
          height: 64,
          width: 64,
          margin: const EdgeInsets.only(bottom: 16),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.1).animate(
              CurvedAnimation(
                parent: _fabAnimationController,
                curve: Curves.easeInOut,
              ),
            ),
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpeechScreen()),
                );
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              elevation: 6,
              shape: const CircleBorder(),
              child: const Icon(Icons.mic, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Signosi',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bridging communication gaps through sign language',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavAction({
    required IconData icon, 
    required bool isActive,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive 
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed ?? () {},
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 24,
              color: isActive 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalPhraseList(BuildContext context, List<PhraseItem> phrases) {
    if (phrases.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline,
        message: 'No phrases available yet'
      );
    }
    
    return SizedBox(
      height: 135,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: phrases.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: 14.0,
              left: index == 0 ? 0 : 0,
            ),
            child: _buildPhraseCard(context, phrases[index]),
          );
        },
      ),
    );
  }

  Widget _buildPhraseCard(BuildContext context, PhraseItem phrase) {
    bool isUsed = phrase.timestamp.contains('Used');
    
    return SizedBox(
      width: 210,
      child: Card(
        elevation: 3,
        shadowColor: Theme.of(context).shadowColor.withOpacity(0.2),
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.07),
            width: 0.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // TODO: Implement phrase card action
          },
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '"${phrase.text}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isUsed ? Colors.blue : Colors.green).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUsed ? Icons.history : Icons.bookmark,
                            size: 14,
                            color: isUsed ? Colors.blue.shade600 : Colors.green.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            phrase.timestamp,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isUsed ? Colors.blue.shade700 : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyPhrasesGrid(BuildContext context, List<EmergencyPhraseItem> phrases) {
    if (phrases.isEmpty) {
      return _buildEmptyState(
        icon: Icons.warning_amber_outlined,
        message: 'No emergency phrases configured'
      );
    }
    
    // Filter phrases by current page
    final currentPagePhrases = phrases.where((phrase) => phrase.page == _currentEmergencyPage).toList();
    
    if (currentPagePhrases.isEmpty) {
      return _buildEmptyState(
        icon: Icons.warning_amber_outlined,
        message: 'No phrases on this page'
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Page title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPageIcon(_currentEmergencyPage),
                      size: 18,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _emergencyPageTitles[_currentEmergencyPage - 1],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: currentPagePhrases.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, index) {
              return _buildEmergencyButton(context, currentPagePhrases[index]);
            },
          ),
          const SizedBox(height: 20),
          _buildPageIndicator(context),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton(BuildContext context, EmergencyPhraseItem phrase) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: phrase.backgroundColor.withOpacity(0.6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: phrase.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () {
            _showEmergencyPhrasesDialog(context, phrase);
          },
          splashColor: phrase.contentColor.withOpacity(0.1),
          highlightColor: phrase.contentColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: phrase.backgroundColor.withOpacity(0.6),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    phrase.icon,
                    color: phrase.contentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  phrase.text,
                  style: TextStyle(
                    color: phrase.contentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyPhrasesDialog(BuildContext context, EmergencyPhraseItem phrase) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: phrase.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: phrase.backgroundColor.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        phrase.icon,
                        color: phrase.contentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        phrase.text,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                
                // Sample phrases
                ...phrase.samplePhrases.map((sample) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          // Close the dialog
                          Navigator.of(context).pop();
                          
                          // Show full screen phrase
                          _showFullScreenPhrase(context, sample, phrase);
                        },
                        borderRadius: BorderRadius.circular(12),
                        splashColor: phrase.backgroundColor.withOpacity(0.5),
                        highlightColor: phrase.backgroundColor.withOpacity(0.3),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sample,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: phrase.backgroundColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.content_copy, size: 18),
                                  onPressed: () {
                                    // TODO: Copy phrase to clipboard
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Phrase copied to clipboard'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  tooltip: 'Copy',
                                  color: phrase.contentColor.withOpacity(0.8),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ).toList(),
                
                const SizedBox(height: 20),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: phrase.backgroundColor.withOpacity(0.8),
                      foregroundColor: phrase.contentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenPhrase(BuildContext context, String phrase, EmergencyPhraseItem emergencyItem) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FullScreenPhrasePage(
          phrase: phrase,
          emergencyItem: emergencyItem,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuart;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
            onPressed: _currentEmergencyPage > 1
                ? () {
                    setState(() {
                      _currentEmergencyPage--;
                    });
                  }
                : null,
            color: Theme.of(context).colorScheme.primary,
            disabledColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          ...List.generate(
            _totalEmergencyPages,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: _currentEmergencyPage == index + 1 ? 14 : 10,
              height: _currentEmergencyPage == index + 1 ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentEmergencyPage == index + 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                boxShadow: _currentEmergencyPage == index + 1 
                    ? [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ] 
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onPressed: _currentEmergencyPage < _totalEmergencyPages
                ? () {
                    setState(() {
                      _currentEmergencyPage++;
                    });
                  }
                : null,
            color: Theme.of(context).colorScheme.primary,
            disabledColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      height: 135,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get icon for each page
  IconData _getPageIcon(int page) {
    switch (page) {
      case 1:
        return Icons.medical_services;
      case 2:
        return Icons.restaurant;
      case 3:
        return Icons.translate;
      default:
        return Icons.category;
    }
  }
}

// --- Data Models ---
class PhraseItem {
  final String text;
  final String timestamp;

  PhraseItem({required this.text, required this.timestamp});
}

class EmergencyPhraseItem {
  final String text;
  final IconData icon;
  final Color backgroundColor;
  final Color contentColor;
  final int page;
  final List<String> samplePhrases;

  EmergencyPhraseItem({
    required this.text,
    required this.icon,
    required this.backgroundColor,
    this.contentColor = Colors.white,
    required this.page,
    required this.samplePhrases,
  });
}

// --- Sample Data ---
final List<PhraseItem> recentlyUsedPhrases = [
  PhraseItem(text: "ආයුබෝවන්, ඔබ කොහොමද?", timestamp: "Used 3h ago"),
  PhraseItem(text: "බොහොම ස්තූතියි", timestamp: "Used 6h ago"),
  PhraseItem(text: "මට උදව් කරන්න පුළුවන්ද?", timestamp: "Used 1d ago"),
  PhraseItem(text: "කරුණාකර මගේ කතාව අසන්න", timestamp: "Used 8h ago"),
  PhraseItem(text: "මට තේරුම් ගන්න බැහැ", timestamp: "Used 12h ago"),
  PhraseItem(text: "නැවත කියන්න", timestamp: "Used 2d ago"),
  PhraseItem(text: "එය කොපමණද?", timestamp: "Used 5h ago"),
  PhraseItem(text: "මට බඩගිනියි", timestamp: "Used 10h ago"),
  PhraseItem(text: "මට වතුර ටිකක් ඕනෑ", timestamp: "Used 7h ago"),
  PhraseItem(text: "කරුණාකර සෙමින් කතා කරන්න", timestamp: "Used 1d ago"),
  PhraseItem(text: "මට ඔබව තේරෙන්නේ නැහැ", timestamp: "Used 9h ago"),
  PhraseItem(text: "මට ඒක අහන්න බැරිවුණා", timestamp: "Used 4h ago"),
  PhraseItem(text: "කරුණාකර නැවත කියන්න", timestamp: "Used 2d ago"),
  PhraseItem(text: "හොඳයි, තුති", timestamp: "Used 5h ago"),
  PhraseItem(text: "සමාවෙන්න", timestamp: "Used 11h ago"),
  PhraseItem(text: "ඔබට සුබ දවසක් වේවා", timestamp: "Used 1d ago"),
  PhraseItem(text: "මම තේරුම් ගත්තා", timestamp: "Used 6h ago"),
];

final List<PhraseItem> savedPhrases = [
  PhraseItem(text: "අද කාලගුණය හොඳයි", timestamp: "Saved 2d ago"),
  PhraseItem(text: "මම බිහිරි කෙනෙක්", timestamp: "Saved 1w ago"),
  PhraseItem(text: "කරුණාකර මට උදව් කරන්න", timestamp: "Saved 2d ago"),
  PhraseItem(text: "මට ඉංග්‍රීසි තේරෙන්නේ නැහැ", timestamp: "Saved 5d ago"),
  PhraseItem(text: "සුබ රාත්රියක්", timestamp: "Saved 1d ago"),
  PhraseItem(text: "කරුණාකර මට උදව් කරන්න", timestamp: "Saved 2d ago"),
  PhraseItem(text: "කෝච්චිය කීයටද පිටත් වන්නේ?", timestamp: "Saved 3d ago"),
  PhraseItem(text: "මට සහය අවශ්‍යයි", timestamp: "Saved 1w ago"),
  PhraseItem(text: "මට පිපාසය දැනෙනවා", timestamp: "Saved 5d ago"),
  PhraseItem(text: "ඔබට සිංහල තේරෙනවාද?", timestamp: "Saved 4d ago"),
];

final List<EmergencyPhraseItem> emergencyPhrases = [
  // Page 1 - Medical
  EmergencyPhraseItem(
    text: "Need Medical Help",
    icon: Icons.medical_services,
    backgroundColor: Colors.red.shade100,
    contentColor: Colors.red.shade700,
    page: 1,
    samplePhrases: [
      "I need a doctor right away",
      "I'm having difficulty breathing",
      "I need medication",
      "I'm having chest pain",
      "Call an ambulance please",
    ],
  ),
  EmergencyPhraseItem(
    text: "Call Help",
    icon: Icons.call,
    backgroundColor: Colors.blue.shade100,
    contentColor: Colors.blue.shade700,
    page: 1,
    samplePhrases: [
      "Please call this number",
      "Call my emergency contact",
      "I need to make an urgent call",
      "Can you help me make a call?",
      "Call 119 for emergency services",
    ],
  ),
  EmergencyPhraseItem(
    text: "Emergency",
    icon: Icons.warning,
    backgroundColor: Colors.orange.shade100,
    contentColor: Colors.orange.shade700,
    page: 1,
    samplePhrases: [
      "This is an emergency",
      "I need immediate help",
      "Please stay with me",
      "Don't leave me alone",
      "Get security personnel",
    ],
  ),
  EmergencyPhraseItem(
    text: "Need Assistance",
    icon: Icons.pan_tool,
    backgroundColor: Colors.yellow.shade200,
    contentColor: Colors.yellow.shade900,
    page: 1,
    samplePhrases: [
      "I need help",
      "Can someone help me?",
      "I require assistance",
      "Please assist me",
      "I can't do this alone",
    ],
  ),
  
  // Page 2 - Daily Needs
  EmergencyPhraseItem(
    text: "Need Water",
    icon: Icons.water_drop,
    backgroundColor: Colors.lightBlue.shade100,
    contentColor: Colors.lightBlue.shade700,
    page: 2,
    samplePhrases: [
      "May I have some water?",
      "I'm very thirsty",
      "Water please",
      "Need a drink",
      "Where can I find water?",
    ],
  ),
  EmergencyPhraseItem(
    text: "Hungry",
    icon: Icons.restaurant,
    backgroundColor: Colors.amber.shade100,
    contentColor: Colors.amber.shade800,
    page: 2,
    samplePhrases: [
      "I'm hungry",
      "Where can I get food?",
      "Is there a restaurant nearby?",
      "I need something to eat",
      "What food options are available?",
    ],
  ),
  EmergencyPhraseItem(
    text: "Need Restroom",
    icon: Icons.wc,
    backgroundColor: Colors.teal.shade100,
    contentColor: Colors.teal.shade700,
    page: 2,
    samplePhrases: [
      "Where is the restroom?",
      "I need to use the bathroom",
      "Is there a toilet nearby?",
      "Restroom, please",
      "Can you show me to the restroom?",
    ],
  ),
  EmergencyPhraseItem(
    text: "Tired",
    icon: Icons.airline_seat_flat,
    backgroundColor: Colors.indigo.shade100,
    contentColor: Colors.indigo.shade700,
    page: 2,
    samplePhrases: [
      "I need to rest",
      "I'm feeling tired",
      "Is there a place to sit?",
      "I need a break",
      "Can I lie down somewhere?",
    ],
  ),
  
  // Page 3 - Communication
  EmergencyPhraseItem(
    text: "I Can't Hear",
    icon: Icons.hearing_disabled,
    backgroundColor: Colors.purple.shade100,
    contentColor: Colors.purple.shade700,
    page: 3,
    samplePhrases: [
      "I am deaf",
      "I can't hear you",
      "Please write it down",
      "I communicate with sign language",
      "Please speak slowly so I can read lips",
    ],
  ),
  EmergencyPhraseItem(
    text: "I'm Lost",
    icon: Icons.location_off,
    backgroundColor: Colors.green.shade100,
    contentColor: Colors.green.shade700,
    page: 3,
    samplePhrases: [
      "I'm lost",
      "Can you help me find my way?",
      "I don't know where I am",
      "I'm looking for this address",
      "Can you show me on a map?",
    ],
  ),
  EmergencyPhraseItem(
    text: "Need Translator",
    icon: Icons.translate,
    backgroundColor: Colors.deepPurple.shade100,
    contentColor: Colors.deepPurple.shade700,
    page: 3,
    samplePhrases: [
      "Do you speak Sinhala/English?",
      "I need a translator",
      "Can you help translate?",
      "Is there anyone who speaks my language?",
      "I don't understand the language",
    ],
  ),
  EmergencyPhraseItem(
    text: "Please Write Down",
    icon: Icons.edit_note,
    backgroundColor: Colors.brown.shade100,
    contentColor: Colors.brown.shade700,
    page: 3,
    samplePhrases: [
      "Please write it down",
      "I need this in writing",
      "Can you show me visually?",
      "Can you draw or write this?",
      "I understand better with written words",
    ],
  ),
];

// Full Screen Phrase Page
class FullScreenPhrasePage extends StatefulWidget {
  final String phrase;
  final EmergencyPhraseItem emergencyItem;

  const FullScreenPhrasePage({
    super.key,
    required this.phrase,
    required this.emergencyItem,
  });

  @override
  State<FullScreenPhrasePage> createState() => _FullScreenPhrasePageState();
}

class _FullScreenPhrasePageState extends State<FullScreenPhrasePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final int _autoCloseSeconds = 10;
  Timer? _timer;
  int _remainingSeconds = 10;

  @override
  void initState() {
    super.initState();
    
    // Set up the animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    
    _animationController.forward();
    
    // Start the auto-close timer
    _remainingSeconds = _autoCloseSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.emergencyItem.backgroundColor.withOpacity(0.95),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_remainingSeconds',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: widget.emergencyItem.backgroundColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.emergencyItem.backgroundColor.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.emergencyItem.icon,
                    color: widget.emergencyItem.contentColor,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.phrase,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.volume_up,
                      label: 'Speak',
                      onPressed: () {
                        // TODO: Implement text-to-speech
                      },
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.content_copy,
                      label: 'Copy',
                      onPressed: () {
                        // TODO: Implement copy to clipboard
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Phrase copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: widget.emergencyItem.backgroundColor.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.emergencyItem.backgroundColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
            color: widget.emergencyItem.contentColor,
            iconSize: 28,
            padding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: widget.emergencyItem.contentColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

