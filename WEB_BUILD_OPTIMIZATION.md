# Flutter Web Build Optimization Guide

## Current Configuration

### Web Renderer Strategy
- **Default**: CanvasKit (high fidelity graphics)
- **Fallback**: HTML/DOM (lighter weight, better mobile support)
- **SkWasm**: For WASM-capable browsers

The build includes multiple renderers so Flutter can choose the best option at runtime.

### File Size Optimization

#### Large Assets (Current Build)
- canvaskit.wasm: ~7-5 MB (graphics rendering engine)
- main.dart.js: ~2.6 MB (app code)
- SkWasm: ~5-3 MB (lightweight WASM alternative)

#### Optimizations Applied
1. **index.html**
   - Added viewport meta for mobile optimization
   - Preload critical scripts (flutter.js, main.dart.js)
   - Added PWA meta tags
   - Removed unused comments

2. **manifest.json**
   - PWA-compliant configuration
   - Thai language support (lang)
   - Proper scope and display settings
   - Maskable icons for modern PWA

3. **vercel.json** (Production Deployment)
   - Cache-Control headers configured
   - Security headers (X-Frame-Options, X-Content-Type-Options, etc)
   - 1-year cache for immutable assets
   - 1-hour revalidation for service worker

4. **.htaccess** (Apache Server)
   - GZIP compression for all text assets
   - Mod_deflate for dynamic compression
   - Cache headers matching Vercel config

5. **netlify.toml** (Netlify Alternative)
   - HTML renderer build optimization
   - Proper cache strategies
   - Security headers

## Deployment Recommendations

### For Mobile Browsers
1. Use **Vercel** with configured cache headers
2. Enable GZIP compression at server level
3. CDN should cache assets for 1 year (immutable)
4. Service worker caches for 1 hour (revalidation)

### Build Command Optimization
```bash
# Release build (smallest size)
flutter build web --release

# With size analysis
flutter build web --release --analyze-size
```

### Future Optimizations
1. **Split builds by renderer** (separate CanvasKit build for high-end devices)
2. **Code splitting** (lazy load components)
3. **Image optimization** (WebP, proper sizing)
4. **PWA offline support** (better service worker strategy)

## Performance Metrics to Monitor
- First Contentful Paint (FCP)
- Largest Contentful Paint (LCP)
- Cumulative Layout Shift (CLS)
- Time to Interactive (TTI)

Run: `flutter build web --analyze-size`
