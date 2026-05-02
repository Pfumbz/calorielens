import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CalorieLens - Privacy Policy</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0C0B09;
      color: #E8E0D0;
      line-height: 1.7;
      padding: 40px 20px;
    }
    .container { max-width: 720px; margin: 0 auto; }
    h1 { font-size: 28px; margin-bottom: 8px; color: #F5EDE0; }
    .brand { color: #D07830; font-style: italic; }
    .updated { color: #8A8070; font-size: 14px; margin-bottom: 32px; }
    h2 { font-size: 18px; color: #F5EDE0; margin-top: 28px; margin-bottom: 10px; border-bottom: 1px solid #2A2820; padding-bottom: 6px; }
    p { margin-bottom: 14px; color: #C8C0B0; font-size: 15px; }
    ul { margin: 10px 0 14px 24px; color: #C8C0B0; font-size: 15px; }
    li { margin-bottom: 6px; }
    a { color: #D07830; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #2A2820; color: #8A8070; font-size: 13px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Privacy Policy</h1>
    <p style="font-size: 20px; color: #F5EDE0;">Calorie<span class="brand">Lens</span></p>
    <p class="updated">Last updated: 2 May 2026</p>

    <p>CalorieLens (&ldquo;the App&rdquo;) is developed and operated by PC Mac Studios (&ldquo;we&rdquo;, &ldquo;us&rdquo;, &ldquo;our&rdquo;). This Privacy Policy explains what information we collect, how we use it, and your choices regarding your data.</p>

    <h2>1. Information We Collect</h2>
    <p>We collect only the information necessary to provide the App&rsquo;s core features:</p>
    <ul>
      <li><strong>Account information:</strong> When you sign in, we collect your email address and authentication credentials via Google Sign-In or email/password registration. This is managed through Supabase Authentication.</li>
      <li><strong>Profile information:</strong> You may optionally provide your name, age, weight, and height to receive personalised calorie targets. This data is stored in your user profile.</li>
      <li><strong>Diary entries:</strong> Meals you log (food names, calorie and macro estimates, timestamps) are stored to track your daily nutrition.</li>
      <li><strong>Scan data:</strong> When you scan a meal using the camera, the image is sent to our AI service (Anthropic Claude) for nutritional analysis. We do not permanently store the images &mdash; they are processed in real time and discarded.</li>
      <li><strong>Usage data:</strong> We track your daily scan and chat counts to manage service limits. No browsing history, location data, or device identifiers are collected.</li>
    </ul>

    <h2>2. How We Use Your Information</h2>
    <p>Your information is used solely to:</p>
    <ul>
      <li>Provide and improve the App&rsquo;s nutrition tracking and AI coaching features</li>
      <li>Calculate personalised calorie goals based on your profile</li>
      <li>Sync your data across devices when signed in</li>
      <li>Enforce daily usage limits for free and Pro tiers</li>
      <li>Display relevant advertisements to free-tier users (via Google AdMob)</li>
    </ul>

    <h2>3. Data Storage and Security</h2>
    <p>Your data is stored securely using Supabase, which provides PostgreSQL database hosting with Row Level Security (RLS) enabled. This means you can only access your own data &mdash; no other user can view your entries, profile, or usage history.</p>
    <p>Guest users (not signed in) have their data stored locally on their device only. This data is not synced to the cloud and is lost if the app is uninstalled.</p>

    <h2>4. Third-Party Services</h2>
    <p>The App integrates with the following third-party services:</p>
    <ul>
      <li><strong>Supabase</strong> (authentication and database): <a href="https://supabase.com/privacy">supabase.com/privacy</a></li>
      <li><strong>Anthropic (Claude AI)</strong> (meal analysis and coaching): <a href="https://www.anthropic.com/privacy">anthropic.com/privacy</a></li>
      <li><strong>Google AdMob</strong> (advertisements for free-tier users): <a href="https://policies.google.com/privacy">policies.google.com/privacy</a>. AdMob may collect device identifiers and ad interaction data as described in Google&rsquo;s privacy policy. Pro users do not see ads.</li>
      <li><strong>Google Sign-In</strong> (optional authentication method): <a href="https://policies.google.com/privacy">policies.google.com/privacy</a></li>
      <li><strong>Pexels</strong> (meal plan images): <a href="https://www.pexels.com/privacy-policy/">pexels.com/privacy-policy</a></li>
      <li><strong>Open Food Facts</strong> (barcode nutrition lookup): <a href="https://world.openfoodfacts.org/privacy">openfoodfacts.org/privacy</a></li>
    </ul>

    <h2>5. Advertisements</h2>
    <p>Free-tier users see banner advertisements served by Google AdMob. AdMob may use cookies and device identifiers to serve personalised ads based on your interests. You can opt out of personalised ads in your device&rsquo;s Google settings. Pro subscribers do not see any advertisements.</p>

    <h2>6. Data Retention</h2>
    <p>Your data is retained for as long as your account is active. If you delete your account, all associated data (profile, diary entries, and usage history) will be permanently removed from our servers within 30 days.</p>

    <h2>7. Your Rights</h2>
    <p>You have the right to:</p>
    <ul>
      <li><strong>Access</strong> your data at any time through the App</li>
      <li><strong>Correct</strong> your profile information in the Settings screen</li>
      <li><strong>Delete</strong> individual diary entries by swiping, or all entries using &ldquo;Clear all&rdquo;</li>
      <li><strong>Delete your account</strong> by contacting us at the email below</li>
      <li><strong>Export your data</strong> by contacting us at the email below</li>
    </ul>
    <p>If you are located in the European Economic Area (EEA), you also have rights under the General Data Protection Regulation (GDPR), including the right to data portability and the right to lodge a complaint with a supervisory authority.</p>
    <p>If you are located in South Africa, you have rights under the Protection of Personal Information Act (POPIA), including the right to request access to and correction of your personal information.</p>

    <h2>8. Children&rsquo;s Privacy</h2>
    <p>CalorieLens is not intended for children under the age of 13. We do not knowingly collect personal information from children. If you believe a child has provided us with personal data, please contact us and we will delete it promptly.</p>

    <h2>9. Changes to This Policy</h2>
    <p>We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated &ldquo;Last updated&rdquo; date. Continued use of the App after changes constitutes acceptance of the revised policy.</p>

    <h2>10. Contact Us</h2>
    <p>If you have any questions about this Privacy Policy or your data, please contact us at:</p>
    <p><a href="mailto:makhuvhap.c@gmail.com">makhuvhap.c@gmail.com</a></p>

    <div class="footer">
      <p>&copy; 2026 PC Mac Studios. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`

serve((_req) => {
  return new Response(html, {
    status: 200,
    headers: new Headers({
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=86400',
    }),
  })
})
