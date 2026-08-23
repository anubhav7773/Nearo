# Nearo UI/UX & Design System Specification (v1.0)

Document Version: `1.0.0`  
Client Framework: `Flutter 3.x (Material 3 with Custom Design Tokens)`  
Domain Ecosystem: `nearo.asiverticals.me`

---

## 1. Design Tokens & Global Style Guide

### 1.1 Color Palette System
All colors must be referenced using strict static `AppColors` constants.

```dart
class AppColors {
  // Primary & Brand Tokens
  static const Color primaryBlue = Color(0xFF1E3A8A);      // Deep Indigo (AppBar, Primary Buttons)
  static const Color primaryHover = Color(0xFF1E40AF);     // Button pressed state
  static const Color accentBlue = Color(0xFF2563EB);       // Links, Active Tabs, Highlights
  
  // Civic SOS & Alert Tokens
  static const Color sosRed = Color(0xFFDC2626);           // SOS Trigger, Emergency Badges
  static const Color sosRedLight = Color(0xFFFEE2E2);      // SOS Background highlight banner
  static const Color sosRedPulse = Color(0x33DC2626);      // Ripple animation ring color

  // Feedback & Trust Tokens
  static const Color verifiedGreen = Color(0xFF16A34A);   // Resident Verification Badge
  static const Color verifiedGreenBg = Color(0xFFDCFCE7); // Badge container background
  static const Color warningOrange = Color(0xFFEA580C);   // Scam alert warnings

  // Neutral & Surface Tokens (Light Theme First)
  static const Color background = Color(0xFFF8FAFC);      // Global Scaffold background (Slate-50)
  static const Color surfaceCard = Color(0xFFFFFFFF);     // Card & Modal surface
  static const Color borderSubtle = Color(0xFFE2E8F0);    // Card 1px borders & dividers
  static const Color borderFocused = Color(0xFF94A3B8);   // Input active borders

  // Typography Tokens
  static const Color textPrimary = Color(0xFF0F172A);     // Headings & post text (Slate-900)
  static const Color textSecondary = Color(0xFF64748B);   // Subtitles, meta-info (Slate-500)
  static const Color textMuted = Color(0xFF94A3B8);       // Placeholders, disabled actions
}
1.2 Spacing & Layout Grid Scale
Base Unit: 4dp

spacing_xs: 4dp

spacing_sm: 8dp

spacing_md: 16dp (Standard screen horizontal padding)

spacing_lg: 24dp

spacing_xl: 32dp

Card Corner Radius: 12.0

Button Corner Radius: 8.0

Input Field Radius: 10.0

Modal Sheet Top Radius: 20.0

2. Global Typography & Text Styles
Font Family: Inter or Plus Jakarta Sans

Display Heading (Auth / Onboarding): fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary, height: 1.25

App Bar Title: fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary

Card Title / Post Header: fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3

Body Regular (Post Content): fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary, height: 1.45

Meta & Distance Subtext: fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary

Badge / Chip Text: fontSize: 11, fontWeight: FontWeight.w600

3. Core Screen Specifications & Widget Layouts
3.1 App Navigation Hierarchy
Bottom Navigation Bar contains 4 fixed destinations:

Radius Feed (Icon: Icons.home_outlined, Active: Icons.home_filled)

Local Directory (Icon: Icons.storefront_outlined, Active: Icons.storefront)

Civic Alerts / SOS (Icon: Icons.shield_outlined, Active: Icons.shield)

Resident Profile (Icon: Icons.person_outline, Active: Icons.person)

3.2 Screen: Hyperlocal Radius Feed (FeedScreen)
Top App Bar Component
Left: Title "Nearo" with subtitle indicating dynamic active area: e.g., "Ayodhya Central (1.5 km)".

Right Actions:

Filter Icon (Categories: All, Civic Issues, Emergency Help, Buy/Sell).

Radius Switcher Chip (Opens a bottom modal to select 1.0 km, 1.5 km, or 3.0 km).

Post Card Component (CommunityFeedCard)
+------------------------------------------------------------------+
| [Avatar]  Nagarik_99 [Verified Badge]         340m away  · 12m   |
| Category: [Civic Issue Chip]                                    |
|------------------------------------------------------------------|
| Post Title: Sector 4 Water Supply Line Maintenance              |
| Description: The municipal pipeline repair is currently         |
| ongoing near the main gate. Water expected by 5 PM.             |
|                                                                  |
| [Optional Attached Photo Thumbnail - 16:9 Aspect Ratio]          |
|------------------------------------------------------------------|
| [▲ Upvote (14)]      [💬 3 Comments]               [↗ Share]     |
+------------------------------------------------------------------+
Card Styling: surfaceCard background, 1px solid borderSubtle, 12dp radius, zero drop-shadow to maintain clean modern flat UI.

Injected Native Ad Component (SponsoredFeedCard)
Injected automatically at index (index % 7 == 0) for users with tier == 'free'.

Distinct Visual Identifiers:

Top-Right Label: Sponsored inside a subtle Slate-100 tag.

Border: 1px solid #CBD5E1.

CTA Button: Full-width Emerald Green #16A34A button: "Chat on WhatsApp" with official WhatsApp icon.

3.3 Screen: Civic SOS & Emergency Alert (SosAlertScreen)
Instant Trigger Interface
+------------------------------------------------------------------+
|                      [ Shield Icon - Alert ]                     |
|                   CIVIC SOS EMERGENCY DISPATCH                   |
|       Tap and hold for 1.5 seconds to alert verified neighbors    |
|                                                                  |
|                                                                  |
|                        /===============\                         |
|                       /   ((  SOS  ))   \                        |
|                      |     HOLD 1.5s     |                       |
|                       \                 /                        |
|                        \===============/                         |
|                                                                  |
| Select Emergency Type:                                           |
| [X] Suspicious Activity/Scam   [ ] Medical   [ ] Fire/Hazard     |
|                                                                  |
| Location Lock: 26.7922° N, 82.1998° E (Accurate to 8 meters)     |
+------------------------------------------------------------------+
Trigger Animation & Safety Guards
Long-Press Protection: User must hold the circular red SOS button for 1500ms to prevent accidental triggers.

Haptic Feedback: Continuous increasing vibration ticks during the 1.5-second hold.

Active SOS Banner: Once dispatched, a sticky red alert banner (#FEE2E2 with #DC2626 text) appears at the top of the entire app with a "Cancel / I Am Safe" button.

3.4 Screen: Resident Profile & Pro Subscription
Visual Elements
Resident Alias badge with anonymous profile avatar.

Pro Tier Upgrade Card (Resident Pro - ₹29/mo):

Gradient banner (#1E3A8A to #2563EB).

Feature bullets:

✓ 100% Ad-Free Clean Community Feed

✓ Priority Alert Dispatch in 3.0 km Radius

✓ Verified Resident Shield Icon on Profile

Action Button: "Upgrade for ₹29 / Month".

4. UI States & Edge Cases
Loading State: Shimmer skeleton placeholders on feed cards (no raw spinning progress indicators in feeds).

Empty State: High-resolution vector icon with contextual text: "No active community updates within 1.5 km. Be the first to share an update!" + Primary "Post Update" button.

Offline State: Top sticky offline banner (#334155) indicating: "Offline mode. Showing cached neighborhood updates."

Permission Denied State (GPS Disabled): Full-screen informational card with a single button: "Enable Precise Location" explaining that local neighborhood feeds require geofencing.