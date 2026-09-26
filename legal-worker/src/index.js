const pages = {
  privacy: {
    title: "Privacy Policy",
    updated: "September 26, 2026",
    content: `
      <p>ScreenMotion is designed to work without an account. Your saved designs, favorites, installation progress, and theme choices remain on your device and are removed when you delete the app.</p>
      <h2>Photos</h2>
      <p>ScreenMotion requests add-only access to Photos solely when you choose to save a wallpaper, video, or Live Photo. It does not read or upload your photo library.</p>
      <h2>Purchases</h2>
      <p>Subscriptions are processed by Apple. RevenueCat helps ScreenMotion load available plans, validate purchase status, and restore access. RevenueCat may process an anonymous app user identifier, purchase and entitlement information, device and app diagnostics, and country or storefront information needed to provide these services. ScreenMotion does not sell this data or use it for cross-app tracking.</p>
      <h2>Firebase</h2>
      <p>New app versions may create a silent anonymous Firebase identity to keep subscription access consistent; that identifier is linked to RevenueCat. Firebase Analytics records app interactions such as onboarding, editing, exporting, and paywall use without sending design names or files. Firebase Crashlytics receives crash reports and limited diagnostic codes. Google processes this information for ScreenMotion as a service provider. No account screen is required.</p>
      <h2>Tracking and advertising</h2>
      <p>ScreenMotion does not request tracking permission, build advertising profiles, or include third-party advertising in the production app.</p>
      <h2>Data retention and choices</h2>
      <p>Local app data remains until you remove it or delete the app. Apple, RevenueCat, and Google retain purchase, identity, analytics, and diagnostic records under their own legal and operational requirements. You can manage or cancel subscriptions in your Apple ID subscription settings and request data deletion through ScreenMotion support.</p>
      <h2>Children</h2>
      <p>ScreenMotion is a general-audience personalization app and does not knowingly collect personal information from children.</p>
      <h2>Changes</h2>
      <p>Material policy changes will be reflected on this page with a new effective date.</p>`
  },
  terms: {
    title: "Terms of Use",
    updated: "September 20, 2026",
    content: `
      <p>By using ScreenMotion, you agree to these terms and Apple’s <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Standard Licensed Application End User License Agreement</a>.</p>
      <h2>Subscriptions</h2>
      <p>ScreenMotion Pro is offered as monthly and yearly auto-renewing subscriptions. The price and billing period shown by the App Store at purchase are controlling. Payment is charged to your Apple ID. Unless canceled at least 24 hours before the end of the current period, the subscription renews automatically. You can manage or cancel it in Apple ID subscription settings. Restore Purchases is available in the app.</p>
      <h2>Wallpaper behavior</h2>
      <p>Interactive motion runs inside ScreenMotion. Exported wallpapers use only the behaviors supported by your device and iOS. You must apply wallpapers, icons, and widgets through Apple’s system interfaces.</p>
      <h2>Your use</h2>
      <p>You may use exported ScreenMotion artwork for personal device customization. You may not resell, redistribute, extract, or claim ownership of ScreenMotion artwork, icon packs, or app assets.</p>
      <h2>Availability</h2>
      <p>Features can vary by device, iOS version, region, and Apple platform capabilities. The app is provided without a promise that every visual effect will work on every device or system screen.</p>
      <h2>Changes and termination</h2>
      <p>We may update the app and these terms. You may stop using the app at any time. Subscription cancellation is handled through Apple.</p>`
  },
  support: {
    title: "ScreenMotion Support",
    updated: "September 20, 2026",
    content: `
      <p>ScreenMotion is a native iPhone theme studio for wallpapers, Live Photos, videos, icons, and widgets.</p>
      <h2>Purchases</h2>
      <p>Open ScreenMotion → Settings → Restore Purchases. Confirm that your device uses the same Apple ID that made the purchase. Subscription management and refunds are handled through Apple.</p>
      <h2>Live Photo and wallpaper setup</h2>
      <p>Save the export to Photos, then apply it from the iOS wallpaper picker. Available Live Photo and spatial effects depend on the device, source image, and iOS version. Home Screen wallpaper remains static.</p>
      <h2>Widgets and icons</h2>
      <p>Follow the in-app installation guide. Widget content can take a moment to refresh after adding it to the Home Screen.</p>
      <h2>Privacy</h2>
      <p>Read the <a href="/privacy">Privacy Policy</a> or review the <a href="/terms">Terms of Use</a>.</p>`
  }
};

function layout(page) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${page.title} — ScreenMotion</title><meta name="description" content="${page.title} for the ScreenMotion iOS app"><style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#090a10;color:#f5f5fa;font:16px/1.65 -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif}main{width:min(760px,calc(100% - 40px));margin:0 auto;padding:72px 0 96px}.brand{color:#9b83ff;letter-spacing:.18em;font-size:12px;font-weight:700}h1{font-size:clamp(38px,8vw,64px);line-height:1.05;margin:14px 0 12px}h2{font-size:22px;margin:34px 0 8px}p{color:#c8c8d6}.updated{color:#858598;font-size:14px;margin-bottom:42px}a{color:#a997ff}nav{display:flex;gap:18px;flex-wrap:wrap;margin-top:52px;padding-top:24px;border-top:1px solid #242533}</style></head><body><main><div class="brand">SCREENMOTION</div><h1>${page.title}</h1><div class="updated">Effective ${page.updated}</div>${page.content}<nav><a href="/support">Support</a><a href="/privacy">Privacy</a><a href="/terms">Terms</a></nav></main></body></html>`;
}

export default {
  async fetch(request) {
    const path = new URL(request.url).pathname.replace(/^\/+|\/+$/g, "") || "support";
    const page = pages[path];
    if (!page) return new Response("Not found", { status: 404 });
    return new Response(layout(page), {
      headers: {
        "content-type": "text/html; charset=UTF-8",
        "cache-control": "public, max-age=3600",
        "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
        "referrer-policy": "no-referrer",
        "x-content-type-options": "nosniff",
        "x-frame-options": "DENY",
        "permissions-policy": "camera=(), microphone=(), geolocation=(), payment=()"
      }
    });
  }
};
