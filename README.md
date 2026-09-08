# 🎉 SyloNow — On-Demand Event & Decor Booking Mobile Application

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Backend](https://img.shields.io/badge/Backend-Supabase_PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Platform](https://img.shields.io/badge/Platform-Android_%7C_iOS-3DDC84?style=for-the-badge)](https://flutter.dev)

> **SyloNow** is a premium consumer mobile application built with **Flutter** and **Supabase** that connects individuals with verified event decoration specialists, curated celebration setups, and on-demand party services.

---

## 🏗️ Architectural Overview

```
┌─────────────────────────────────────────────────────────────┐
│                       CUSTOMER MOBILE UI                    │
│  • Visual Event Catalog & Curated Theme Discovery           │
│  • Interactive Customization & Package Configuration        │
│  • Booking Calendar & Slot Availability Scheduler           │
│  • Live Order Tracker & Fulfillment Progression             │
├─────────────────────────────────────────────────────────────┤
│                     DATA & SYNCHRONIZATION                  │
│  • Supabase PostgreSQL Database with Row-Level Security     │
│  • Real-Time Order Status Subscriptions (WebSockets)        │
│  • Secure Token Storage & Encrypted User Session Cache      │
├─────────────────────────────────────────────────────────────┤
│                    EXTERNAL INTEGRATIONS                    │
│  • MSG91 Transactional SMS Gateway Notifications            │
│  • Secure Payment Workflows                                 │
│  • OneSignal Real-Time Status Alerts                        │
└─────────────────────────────────────────────────────────────┘
```

---

## ✨ Features

- 🎈 **Curated Celebration Themes:** High-resolution photo catalogs of verified decoration setups for birthdays, weddings, baby showers, and corporate events.
- 📅 **Dynamic Date & Time Slot Engine:** Intelligent calendar scheduling checking real-time vendor capacity before booking confirmation.
- 🚚 **Live Order Tracking:** Real-time visual progress bar tracking orders from initial confirmation to on-site decor completion.
- 💬 **Instant Status Updates:** Transactional SMS notifications and in-app alerts powered by MSG91 and Supabase Edge Functions.
- 🔒 **Secure Authentication:** Multi-provider authentication supporting passwordless OTP login and email authentication.

---

## 📂 Project Structure

```
lib/
├── core/                  # Theme, colors, utilities, API constants
├── models/                # Event packages, bookings, user profile models
├── screens/               # Home, category detail, booking flow, order history
├── services/              # Supabase API, notifications, analytics
└── widgets/               # Reusable package cards, booking summary, review dialogs
```

---

## 🚀 Quick Setup & Installation

### 1. Clone the Repository
```bash
git clone https://github.com/sangamesh5588/sylonow_user_app_main.git
cd sylonow_user_app_main
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
```ini
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 4. Run Application
```bash
flutter run
```

---

## 🛡️ License
Copyright © 2026 Sangamesh K. All rights reserved.