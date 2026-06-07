# LosCheck UX/UI Design System — ระดับเทพ 🎨

## 📋 สารบัญ
1. **Design Principles**
2. **Color & Typography System**
3. **Component Patterns**
4. **Spacing & Layout**
5. **Micro-interactions & Animations**
6. **Accessibility (WCAG A+ Level)**
7. **Dark Mode Strategy**
8. **Implementation Examples**

---

## 🎯 Design Principles

### 1. **Clarity First** (ความชัดเจน)
- ข้อมูลหลักต้องอ่านได้ชัด ณ ระยะ arm's length
- Typography hierarchy ต้องมี 3 ระดับชัด: Heading, Body, Caption
- Call-to-action (CTA) ต้องเด่นและชัด

**ปัญหาปัจจุบัน:**
- ✗ Heading size ไม่พอแตกต่าง (headlineMedium ไม่เด่นพอ)
- ✗ Stat card values ต้อง size ใหญ่ขึ้น (impact)

### 2. **Consistency** (ความสอดคล้อง)
- ใช้ Design Tokens เก็บค่า spacing, radius, shadow ไว้กลาง
- Component variants ต้องมีคุณสมบัติเหมือนกัน
- Color palette ต้อง semantic (ความหมายชัด)

### 3. **Proximity & Grouping** (การจัดกลุ่ม)
- Related items ต้องใกล้กัน
- Spacing ต้องสื่อ relationship ระหว่าง elements

**ปัญหาปัจจุบัน:**
- ✗ Dashboard section spacing ไม่สม่ำเสมอ (20 vs 32)
- ✗ Stat cards ไม่มี visual "breathing room" เพียงพอ

---

## 🎨 Color & Typography System

### **Color Palette (ปรับปรุง)**

#### Primary (Teal - Current)
```
Teal 50:   #F0F7F6  (background lightest)
Teal 100:  #B2DFDB  (light backgrounds)
Teal 700:  #00897B  ✓ Primary brand
Teal 900:  #004D40  (dark mode primary)
```

#### Secondary Accent (Amber - Current - ปรับปรุง)
```
Amber 50:  #FFF8E1
Amber 700: #FBC02D  ← ปรับจาก Amber.shade700 (ดังขึ้น, better contrast)
Amber 900: #F57F17  (dark mode secondary)
```

#### Success / Error / Warning (เพิ่มใหม่)
```
Success:   #4CAF50 (Green - positive actions, confirmations)
Error:     #F44336 (Red - destructive, errors)
Warning:   #FF9800 (Orange - alerts, caution)
Info:      #2196F3 (Blue - informational)
```

#### Neutral (เพิ่มใหม่ - for text, borders, backgrounds)
```
Gray 50:   #FAFAFA  (light background)
Gray 200:  #EEEEEE  (subtle borders)
Gray 600:  #757575  (secondary text)
Gray 900:  #212121  (dark text, dark mode text)
```

### **Typography System (ปรับปรุง)**

#### Font Stack (เพิ่มใหม่)
```dart
// เลือก: Mitr (ไทย ดี), Roboto (ภาษา Latin)
// ลบ: ตัวอักษร default Material ที่ไม่เหมาะกับไทยมาก
```

#### Type Scale (ตารางขนาดตัวอักษร)
```
DisplayLarge:     48px / 56px line-height   (hero/app title)
DisplayMedium:    40px / 48px line-height
DisplaySmall:     32px / 40px line-height

HeadlineLarge:    32px / 40px               (page title, section header)
HeadlineMedium:   28px / 36px               (stat labels, major headings)
HeadlineSmall:    24px / 32px               (subsection headers)

TitleLarge:       22px / 28px               (dialog titles, card titles)
TitleMedium:      16px / 24px               (section titles)
TitleSmall:       14px / 20px               (small titles)

BodyLarge:        16px / 24px line-height  (main body, large text)
BodyMedium:       14px / 20px line-height  (standard body)
BodySmall:        12px / 16px line-height  (captions, hints)

LabelLarge:       14px / 20px (semibold)   (buttons, labels)
LabelMedium:      12px / 16px (semibold)   (small labels)
LabelSmall:       11px / 16px (semibold)   (badges, tags)
```

**ปัญหาปัจจุบัน:**
- ✗ ค่า text ใน Stat Cards ควรใช้ DisplaySmall (ตอนนี้ ไม่ใหญ่พอ)
- ✗ Typography ไม่ semantic (ใช้ copyWith มากเกินไป)

---

## 🧩 Component Design Patterns

### **1. Stat Card (Dashboard)**

#### ปัญหาปัจจุบัน:
- Icon size fixed 48px (ดีแล้ว) ✓
- Value text size ไม่พอใหญ่ (ควร 32-40px)
- Gradient นำไปหา contrast ของ text (เสี่ยง accessibility)
- Hover/tap feedback ไม่มี

#### ปรับปรุงไป:

```dart
class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
    required this.textColor,
    this.onTap,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Gradient gradient;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.textColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: widget.textColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      widget.icon,
                      color: widget.textColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.textColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Value (ใหญ่เด่น)
              Text(
                widget.value,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: widget.textColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              
              // Unit (small label)
              Text(
                widget.unit,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Improvements:**
- ✅ Value text ขนาด displaySmall (32px) → impact สูง
- ✅ Icon ในกล่อง subtle background → contrast ดี
- ✅ Press animation (scale 98%) → tactile feedback
- ✅ Shadow ที่สวย → depth perception
- ✅ Accessibility: alpha transparency แทน solid color

### **2. List Tile (Customer/Trip Records)**

#### ปัญหาปัจจุบัน:
- Row layout ไม่ responsive (ทำให้ overflow มือถือเล็ก)
- ไม่มี swipe action หรือ long-press menu
- Leading indicator ไม่มี

#### ปรับปรุง:

```dart
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    required this.leadingColor,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final Color leadingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Leading indicator
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: leadingColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content (flexible, responsive)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Trailing value
                Text(
                  trailing,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                
                // Chevron icon
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Improvements:**
- ✅ Flexible layout (ไม่ overflow บนมือถือเล็ก)
- ✅ Colored leading bar → visual categorization
- ✅ InkWell ripple feedback → tactile
- ✅ Chevron → affordance (สั่งว่าไปต่อได้)

---

## 📏 Spacing & Layout (8px Grid System)

### **Consistent Spacing Values**

```dart
// ใน lib/core/design_tokens.dart
class DesignTokens {
  // Spacing (8px base unit)
  static const double spacingXs = 4.0;    // 4px
  static const double spacingXs2 = 8.0;   // 8px
  static const double spacingS = 12.0;    // 12px
  static const double spacingM = 16.0;    // 16px
  static const double spacingL = 24.0;    // 24px
  static const double spacingXl = 32.0;   // 32px
  static const double spacingXxl = 48.0;  // 48px

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusCircle = 999.0;

  // Elevation/Shadows
  static const double elevationXs = 2.0;
  static const double elevationSm = 4.0;
  static const double elevationMd = 8.0;
  static const double elevationLg = 12.0;

  // Typography
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightLoose = 1.75;
}
```

**ใช้ในโค้ด:**
```dart
// ❌ Old
Padding(padding: const EdgeInsets.all(20), ...)
Padding(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), ...)

// ✅ New
Padding(
  padding: EdgeInsets.all(DesignTokens.spacingM),
  ...
)
SizedBox(height: DesignTokens.spacingL),
```

---

## ✨ Micro-interactions & Animations

### **1. Entrance Animations (Fade + Slide)**

```dart
class FadeInSlide extends StatefulWidget {
  const FadeInSlide({
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.0, end: 1.0)),
      child: SlideTransition(
        position: _controller.drive(
          Tween(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: widget.child,
      ),
    );
  }
}
```

**ใช้งาน:**
```dart
FadeInSlide(
  delay: Duration(milliseconds: index * 100),
  child: _StatCard(...),
)
```

### **2. Loading States (Skeleton Pulse)**

```dart
class ShimmerPulse extends StatefulWidget {
  const ShimmerPulse({
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerPulse> createState() => _ShimmerPulseState();
}

class _ShimmerPulseState extends State<ShimmerPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            widget.baseColor,
            widget.highlightColor,
            widget.baseColor,
          ],
          stops: [
            _controller.value - 0.3,
            _controller.value,
            _controller.value + 0.3,
          ],
        ).createShader(bounds);
      },
      child: widget.child,
    );
  }
}
```

---

## ♿ Accessibility (WCAG Level AA+)

### **Color Contrast Requirements**
- ✅ Normal text (14px): 4.5:1 minimum
- ✅ Large text (18px+): 3:1 minimum
- ✅ UI components: 3:1 minimum

### **ตรวจสอบ Contrast**

```dart
// ❌ Bad (teal on light gray = 3.2:1)
Text('Label', style: TextStyle(color: Colors.teal.shade700))

// ✅ Good (teal on white = 5.8:1)
Text('Label', style: TextStyle(color: Colors.teal.shade900))
```

### **Font Scaling Support**

```dart
// ❌ Hard-coded sizes
Text('Label', style: TextStyle(fontSize: 16))

// ✅ Responsive to system settings
Text(
  'Label',
  style: Theme.of(context).textTheme.bodyMedium,
)
```

### **Touch Target Sizes**
- ✅ Minimum 48x48 dp (for fingers)
- ✅ Buttons/Tappable areas ≥ 48dp

### **Semantic HTML / Semantics**

```dart
// ✅ ใช้ semantics labels
Tooltip(
  message: 'เปิด menu settings',
  child: IconButton(icon: Icon(Icons.settings), onPressed: () {}),
)

// ✅ Screen reader support
Semantics(
  label: 'จำนวนรายได้รวม 5000 บาท',
  child: Text('5000'),
)
```

---

## 🌙 Dark Mode Strategy

### **Current Issues:**
- ✗ Dark mode AppBar (teal.shade900) + text ไม่ contrast พอ
- ✗ Gradient ใน stat cards ไม่ optimize สำหรับ dark

### **ปรับปรุง:**

```dart
// ในธีม Dark
darkTheme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.tealAccent,
    primary: Colors.tealAccent.shade200,  // ✅ ต่อจาก teal.shade400
    secondary: Colors.amberAccent,
    brightness: Brightness.dark,
    
    // ✅ Explicit surface colors
    surface: Color(0xFF121212),           // Very dark
    surfaceContainerHighest: Color(0xFF1F1F1F),
    onSurface: Color(0xFFFFFFFF),         // White text
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1F1F1F),   // ✅ Lighter than full black
    foregroundColor: Colors.white,
    elevation: 0,                          // ✅ ไม่ต้อง elevation บน dark
  ),
),
```

---

## 📱 Mobile-First Responsive Design

### **Breakpoints**

```dart
class Breakpoints {
  static const double mobile = 480;      // max 480px
  static const double tablet = 768;      // 480-768px
  static const double desktop = 1200;    // 768px+
}

bool isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < Breakpoints.tablet;
```

### **Layout Adjustments**

```dart
// ❌ Hard-coded constraints
ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), ...)

// ✅ Responsive
ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: isMobile(context) ? double.infinity : 800,
  ),
  ...
)
```

---

## 🎬 Implementation Roadmap

### **Phase 1: Design Tokens (Week 1)**
1. สร้าง `lib/core/design_tokens.dart`
2. ลบ hard-coded values ออก
3. เชื่อม theme กับ tokens

### **Phase 2: Component Library (Week 2)**
1. Refactor stat cards (ขนาด, animation)
2. ปรับปรุง list tiles (responsive, indicator)
3. เพิ่ม micro-interactions (fade, scale)

### **Phase 3: Dark Mode & Accessibility (Week 3)**
1. Fix contrast issues ใน dark mode
2. เพิ่ม semantic labels
3. ทดสอบ accessibility tools (axe)

### **Phase 4: Polish (Week 4)**
1. เพิ่ม empty states + illustrations
2. ปรับ animations/transitions
3. Test บน multiple devices

---

## 📚 Tools & References

### **Design Audit Tools**
- **Contrast Checker**: https://webaim.org/resources/contrastchecker/
- **Material Design 3 Colors**: https://m3.material.io/styles/color/the-color-system/color-roles
- **Figma Community**: https://www.figma.com/community

### **Flutter-Specific**
- **FlutterFlow**: Low-code UI builder (optional prototyping)
- **GetWidget**: Pre-built components library
- **LayoutBuilder**: For responsive design

---

## 🎯 Quick Wins (Implement Now)

1. **Increase Stat Card Value Size** → DisplaySmall (32px)
2. **Add Design Tokens File** → Remove magic numbers
3. **Fix Dark Mode Contrast** → Lighter surfaces
4. **Add Press Animation** → ScaleTransition (scale: 0.98)
5. **Add Loading Skeletons** → ShimmerPulse effect

**ผลลัพธ์:** App จะดูระดับ "professional" ภายใน 1 สัปดาห์!
