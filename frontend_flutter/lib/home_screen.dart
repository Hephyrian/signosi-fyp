import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 150, // Increased width to accommodate logo and text
        leading: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Image.asset(
                'assets/images/signosi_logo_hand.png', // Placeholder - replace with your actual asset
                height: 24, // Adjust as needed
                // You'll need to add this asset to your pubspec.yaml and assets folder
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Signosi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                // color: Colors.orange, // Consider using theme colors
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // TODO: Implement profile action
            },
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Theme.of(context).colorScheme.surface, // M3 surface color
        elevation: 0, // M3 often uses flat app bars or subtle elevation
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildSectionTitle(context, 'Recently Used'),
            _buildHorizontalPhraseList(context, recentlyUsedPhrases),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Saved'),
            _buildHorizontalPhraseList(context, savedPhrases),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Emergency Phrases'),
            _buildEmergencyPhrasesGrid(context, emergencyPhrases),
            const SizedBox(height: 80), // Space for the microphone button area
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          // TODO: Implement tap to speak
        },
        backgroundColor: Colors.orange, // Theme primary or custom
        child: const Icon(Icons.mic, color: Colors.white, size: 40),
        // elevation: 2.0, // M3 might prefer lower/no elevation for FABs if docked
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHorizontalPhraseList(BuildContext context, List<PhraseItem> phrases) {
    if (phrases.isEmpty) {
      return const Center(child: Text('No phrases yet.'));
    }
    return SizedBox(
      height: 100, // Adjust height as needed
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: phrases.length,
        itemBuilder: (context, index) {
          return _buildPhraseCard(context, phrases[index]);
        },
      ),
    );
  }

  Widget _buildPhraseCard(BuildContext context, PhraseItem phrase) {
    return SizedBox(
      width: 180, // Adjust width as needed
      child: Card(
        // elevation: 1, // M3 uses subtle elevation or surface tints
        color: Theme.of(context).colorScheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '"${phrase.text}"',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                phrase.timestamp,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyPhrasesGrid(BuildContext context, List<EmergencyPhraseItem> phrases) {
    if (phrases.isEmpty) {
        return const Center(child: Text('No emergency phrases configured.'));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // To disable GridView's scrolling
      itemCount: phrases.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8, // Adjust aspect ratio
      ),
      itemBuilder: (context, index) {
        return _buildEmergencyButton(context, phrases[index]);
      },
    );
  }

  Widget _buildEmergencyButton(BuildContext context, EmergencyPhraseItem phrase) {
    return ElevatedButton.icon(
      icon: Icon(phrase.icon, color: phrase.contentColor),
      label: Text(
        phrase.text,
        style: TextStyle(color: phrase.contentColor),
        textAlign: TextAlign.center,
      ),
      onPressed: () {
        // TODO: Implement emergency phrase action
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: phrase.backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // elevation: 1, // M3 style
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(), // Creates the notch for the FAB
      notchMargin: 8.0, // Margin for the notch
      color: Theme.of(context).colorScheme.surfaceVariant,
      // elevation: 0, // M3 often has flat bottom app bars
      child: SizedBox(
        height: 70, // Increased height to accommodate text below icons
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildBottomNavItem(context, Icons.settings, 'Settings', () {
              // TODO: Navigate to Settings
            }),
            const SizedBox(width: 40), // Placeholder for the FAB notch
            _buildBottomNavItem(context, Icons.help_outline, 'Help', () {
              // TODO: Navigate to Help
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24), // For ripple effect
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Data Models (Placeholder) ---
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


  EmergencyPhraseItem({
    required this.text,
    required this.icon,
    required this.backgroundColor,
    this.contentColor = Colors.white, // Default content color
  });
}

// --- Sample Data (Placeholder) ---
final List<PhraseItem> recentlyUsedPhrases = [
  PhraseItem(text: "Hello, how are you?", timestamp: "Used 2h ago"),
  PhraseItem(text: "Thank you very much", timestamp: "Used 5h ago"),
  PhraseItem(text: "Can I get some help?", timestamp: "Used 1d ago"),
];

final List<PhraseItem> savedPhrases = [
  PhraseItem(text: "Hello, how are you?", timestamp: "Saved 2h ago"),
  PhraseItem(text: "Thank you very much", timestamp: "Saved 5h ago"),
];

final List<EmergencyPhraseItem> emergencyPhrases = [
  EmergencyPhraseItem(
    text: "Need Medical Help",
    icon: Icons.medical_services,
    backgroundColor: Colors.red.shade100,
    contentColor: Colors.red.shade700,
  ),
  EmergencyPhraseItem(
    text: "Call Help",
    icon: Icons.call,
    backgroundColor: Colors.blue.shade100,
    contentColor: Colors.blue.shade700,
  ),
  EmergencyPhraseItem(
    text: "Emergency",
    icon: Icons.warning,
    backgroundColor: Colors.orange.shade100,
    contentColor: Colors.orange.shade700,
  ),
  EmergencyPhraseItem(
    text: "Need Assistance",
    icon: Icons.pan_tool, // Example: hand icon
    backgroundColor: Colors.yellow.shade200, // Adjusted for better visibility
    contentColor: Colors.yellow.shade900, // Darker for contrast
  ),
]; 