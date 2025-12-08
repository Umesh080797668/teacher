# UI Components Reference

## Color Palette

### Primary Colors
- **Primary**: `#6750A4` - Purple (Main brand color)
- **Primary Light**: `#E8DEF8` - Light Purple (Backgrounds)
- **Primary Dark**: `#4F378B` - Dark Purple (Emphasis)

### Status Colors
| Status | Color | Hex | Usage |
|--------|-------|-----|-------|
| Present | 🟢 Green | `#4CAF50` | Positive attendance status |
| Absent | 🔴 Red | `#E53935` | Negative attendance status |
| Late | 🟠 Orange | `#FF9800` | Warning attendance status |
| Success | 🟢 Green | `#00C853` | Success messages |
| Error | 🔴 Red | `#D32F2F` | Error messages |
| Warning | 🟠 Orange | `#FF6F00` | Warning messages |
| Info | 🔵 Teal | `#00BFA5` | Information messages |

## Typography

### Font Family
- **Primary Font**: Poppins (via Google Fonts)

### Text Styles
- **Headline Large**: 32px, Bold
- **Headline Medium**: 24px, Bold
- **Subtitle**: 16px, Semi-Bold (600)
- **Body**: 14px, Regular
- **Caption**: 12px, Regular

## Spacing System

| Size | Value | Usage |
|------|-------|-------|
| XS | 4px | Minimal spacing |
| SM | 8px | Small spacing |
| MD | 16px | Standard spacing |
| LG | 24px | Large spacing |
| XL | 32px | Extra large spacing |
| XXL | 48px | Maximum spacing |

## Border Radius

| Size | Value | Usage |
|------|-------|-------|
| SM | 8px | Small elements |
| MD | 12px | Buttons, inputs |
| LG | 16px | Cards |
| XL | 20px | Large cards |
| Round | 100px | Circular elements |

## Elevation (Shadow)

| Level | Value | Usage |
|-------|-------|-------|
| None | 0 | Flat surfaces |
| SM | 2 | Subtle elevation |
| MD | 4 | Standard cards |
| LG | 8 | Floating elements |
| XL | 16 | Modals, dialogs |

## Components

### 1. Feature Card (Home Screen)
```dart
_FeatureCard(
  title: 'Students',
  subtitle: 'Manage student records',
  icon: Icons.people_rounded,
  color: Color(0xFF6750A4),
  onTap: () => // Navigation
)
```

**Features:**
- Gradient background
- Icon with colored container
- Title and subtitle
- Tap animation
- Shadow effect

### 2. Status Chip (Attendance)
```dart
_StatusChip(
  label: 'P',
  icon: Icons.check_circle,
  color: Colors.green,
  isSelected: true,
  onTap: () => // Status change
)
```

**Features:**
- Toggle state
- Color animation
- Icon display
- Border highlight when selected

### 3. Student Card
```dart
Card(
  child: ListTile(
    leading: CircleAvatar(/* Initial */),
    title: Text(/* Name */),
    subtitle: Column(
      children: [
        Row(Icon + Text), // ID
        Row(Icon + Text), // Email
      ],
    ),
    trailing: Icon(Icons.chevron_right),
  ),
)
```

**Features:**
- Avatar with student initial
- Name and ID display
- Optional email display
- Swipe-to-delete action
- Chevron indicator

### 4. Statistics Card
```dart
_StatCard(
  title: 'Present',
  value: '42',
  icon: Icons.check_circle,
  color: Colors.green,
)
```

**Features:**
- Large value display
- Icon with color
- Title label
- White background
- Subtle shadow

### 5. Info Card
```dart
InfoCard(
  title: 'Total Students',
  value: '150',
  icon: Icons.people,
  color: Theme.of(context).colorScheme.primary,
)
```

**Features:**
- Centered layout
- Icon, value, title stack
- Color-coded
- Optional tap action

### 6. Custom Button
```dart
CustomButton(
  text: 'Save Student',
  icon: Icons.save,
  onPressed: () => // Action,
  backgroundColor: Colors.green,
  isLoading: false,
  isFullWidth: true,
)
```

**Features:**
- Icon + text layout
- Loading state
- Custom colors
- Full width option
- Rounded corners

### 7. Status Badge
```dart
StatusBadge(
  status: 'present',
  color: Colors.green,
  icon: Icons.check_circle,
)
```

**Features:**
- Icon + text
- Rounded container
- Colored border
- Transparent background

### 8. Empty State
```dart
EmptyState(
  icon: Icons.people_outline,
  title: 'No students yet',
  message: 'Add your first student to get started',
  action: CustomButton(/* Add Student */),
)
```

**Features:**
- Large icon
- Title and message
- Optional action button
- Centered layout

## Screen Layouts

### Home Screen
```
┌─────────────────────────────────┐
│ Welcome Back!          [Avatar] │
│ Manage your classroom...        │
├─────────────────────────────────┤
│ ┌──────────┬──────────┐        │
│ │ Students │ Mark     │        │
│ │ 👥       │ Attend   │        │
│ │          │ ✓        │        │
│ └──────────┴──────────┘        │
│ ┌──────────┬──────────┐        │
│ │ View     │ Reports  │        │
│ │ Records  │ 📊       │        │
│ │ 📈       │          │        │
│ └──────────┴──────────┘        │
└─────────────────────────────────┘
```

### Students Screen
```
┌─────────────────────────────────┐
│ ← Students                      │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ Total: 42    Active: 42     │ │
│ └─────────────────────────────┘ │
│                                 │
│ [+ Add New Student]             │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ [A] John Doe                │ │
│ │     ID: STU001              │ │
│ │     ✉ john@example.com      │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ [J] Jane Smith              │ │
│ │     ID: STU002              │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### Mark Attendance Screen
```
┌─────────────────────────────────┐
│ ← Mark Attendance               │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 📅 Monday, Dec 7, 2025      │ │
│ │ ⏰ [Morning] [Afternoon]    │ │
│ └─────────────────────────────┘ │
│                                 │
│ Present: 2  Absent: 1  Late: 0  │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ [J] John Doe     [P][A][L] │ │
│ │     ID: STU001              │ │
│ └─────────────────────────────┘ │
│                                 │
│                  [Save (3)] ➤  │
└─────────────────────────────────┘
```

### View Attendance Screen
```
┌─────────────────────────────────┐
│ ← View Attendance          [📊] │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🔍 [December ▼] [2025 ▼]   │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌────┬────┬────┐               │
│ │ ✓  │ ✗  │ ⏰ │               │
│ │ 25 │ 10 │ 5  │               │
│ │Pre │Abs │Lat │               │
│ └────┴────┴────┘               │
│                                 │
│ ┌─── Pie Chart ───┐            │
│ │                 │            │
│ │    🟢 62%       │            │
│ │  🔴  🟠         │            │
│ │  25%  13%       │            │
│ └─────────────────┘            │
│                                 │
│ Attendance Records (40)         │
│ ┌─────────────────────────────┐ │
│ │ ✓ STU001                    │ │
│ │   Monday, Dec 7             │ │
│ │   MORNING      [PRESENT]   │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

## Animations

1. **Card Tap**: Scale animation on press
2. **Status Selection**: Color transition (200ms)
3. **Form Expand**: Height animation (300ms)
4. **List Items**: Fade in on load
5. **Swipe Actions**: Slide animation

## Icons

| Feature | Icon | Material Icon Name |
|---------|------|-------------------|
| Students | 👥 | `people_rounded` |
| Attendance | ✓ | `check_circle_rounded` |
| Analytics | 📊 | `analytics_rounded` |
| Reports | 📈 | `assessment_rounded` |
| Calendar | 📅 | `calendar_today` |
| Time | ⏰ | `access_time` |
| Present | ✓ | `check_circle` |
| Absent | ✗ | `cancel` |
| Late | ⏰ | `access_time` |
| Filter | 🔍 | `filter_list` |
| Add | ➕ | `add` |
| Delete | 🗑️ | `delete` |
| Edit | ✏️ | `edit` |
| Save | 💾 | `save` |

## Responsive Breakpoints

- **Mobile**: < 600px (primary target)
- **Tablet**: 600px - 900px
- **Desktop**: > 900px

Currently optimized for mobile devices.

---

This reference guide provides all the visual constants and components used throughout the app for consistent design implementation.
