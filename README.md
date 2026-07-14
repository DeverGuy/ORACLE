# ORACLE — School Fee Management System

A comprehensive and modern School Fee Management System. ORACLE streamlines the fee collection, tracking, and management processes for schools, organizations, and parents. 

## 🚀 Key Features
- **Automated fee tracking:** Schedules, instalments and grace periods handled automatically with due-date reminders.
- **Digital receipts & history:** Instant receipt generation, searchable payment history, and exportable audit trails for accounting.
- **Role-based access:** Separate admin and staff privileges to protect financial data and control verification workflows.
- **Real-time reporting:** Dashboards and interactive charts for collections, outstanding balances and trend analysis.
- **Secure cloud sync:** Encrypted storage, daily backups and cross-device consistency minimise data loss risk.

## 🛠️ Technology Stack
- **Frontend:** [Flutter](https://flutter.dev) (Cross-platform Web, Mobile, Desktop)
- **Backend as a Service:** [Supabase](https://supabase.com) (Authentication, PostgreSQL Database, Storage)
- **State Management:** [Riverpod](https://riverpod.dev)
- **Routing:** [GoRouter](https://pub.dev/packages/go_router)
- **Charts:** [FL Chart](https://pub.dev/packages/fl_chart)

## 🏗️ Project Architecture
- `lib/core/` - Providers, models, themes, and utility classes.
- `lib/features/` - Domain-specific modules:
  - `/admin` - Admin portal views
  - `/auth` - Login and authentication workflows
  - `/dashboard` - Overview and statistics
  - `/students` - Student directory and details
  - `/payments` - Payment processing and history
- `lib/router/` - GoRouter configuration
- `lib/shared/` - Reusable UI components and widgets

## ⚙️ Installation & Setup Guide

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>=3.0.0 <4.0.0)
- Supabase Account and Project

### Steps
1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd ORACLE
   ```
2. **Install dependencies**
   ```bash
   flutter pub get
   ```
3. **Configure Supabase**
   - Provide your Supabase URL and Anon Key in your environment or within `lib/main.dart` / configuration files.
4. **Run the application**
   ```bash
   # Run on web
   flutter run -d chrome
   ```

## 🔗 APIs & Integrations
- **Supabase Auth:** Handles user authentication and role-based access control (Admin vs. Org vs. User).
- **Supabase Database:** PostgreSQL backend storing students, organizations, transactions, and verification workflows.

## 🌐 Live Demo
*(Insert Live Web URL Here once deployed)*
