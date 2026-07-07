"""
Invite Landing Page

Renders the HTML page served at GET /join/{code}. The page:
- Tries to open the native app via the loverscompass:// deep link
- Falls back to the App Store (if APP_STORE_URL is configured)
- Always offers the web app (served at /) with the code prefilled

The code is validated against the pairing-code charset before this is
called, so interpolation is safe.
"""

import html


def render_invite_page(code: str, app_store_url: str) -> str:
    """Return the invite landing page HTML for a validated pairing code."""
    safe_code = html.escape(code)
    store_url = html.escape(app_store_url) if app_store_url else ""

    store_button = (
        f'<a class="btn btn-secondary" id="btn-store" href="{store_url}">'
        f'Get the iPhone App</a>'
        if store_url
        else ""
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>You're invited to Lover's Compass 💘</title>
<meta property="og:title" content="Join me on Lover's Compass 💘">
<meta property="og:description" content="A compass that always points to your lover. Tap to pair with me!">
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    min-height: 100vh;
    display: flex; align-items: center; justify-content: center;
    background: linear-gradient(135deg, #fff3f5 0%, #ffe9ee 50%, #fadfe6 100%);
    color: #ff4571;
    padding: 24px;
    text-align: center;
  }}
  .card {{
    background: rgba(255,255,255,0.8);
    border-radius: 28px;
    padding: 40px 28px;
    max-width: 400px; width: 100%;
    box-shadow: 0 20px 50px rgba(255,107,138,0.18);
  }}
  .heart {{ font-size: 52px; margin-bottom: 12px; animation: pulse 1.4s ease-in-out infinite; }}
  @keyframes pulse {{ 0%,100% {{ transform: scale(1); }} 50% {{ transform: scale(1.12); }} }}
  h1 {{ font-size: 24px; margin-bottom: 6px; }}
  p.sub {{ color: #ff6b8a; font-size: 15px; margin-bottom: 24px; }}
  .code {{
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 34px; font-weight: 700; letter-spacing: 4px;
    background: #fff; border: 2px solid rgba(255,107,138,0.3);
    border-radius: 16px; padding: 14px 10px; margin-bottom: 8px;
    user-select: all; -webkit-user-select: all;
  }}
  .copy-hint {{ font-size: 12px; color: #ffa2b5; margin-bottom: 24px; }}
  .btn {{
    display: block; width: 100%; padding: 15px; border-radius: 16px;
    font-size: 16px; font-weight: 600; text-decoration: none;
    margin-bottom: 12px; cursor: pointer; border: none;
  }}
  .btn-primary {{
    background: linear-gradient(90deg, #ff6b8a, #ff4571); color: #fff;
    box-shadow: 0 8px 20px rgba(255,69,113,0.3);
  }}
  .btn-secondary {{
    background: #fff; color: #ff4571; border: 2px solid #ff4571;
  }}
  .btn-tertiary {{ background: none; color: #ff6b8a; font-size: 14px; }}
  .note {{ font-size: 12px; color: #ffa2b5; margin-top: 16px; line-height: 1.5; }}
</style>
</head>
<body>
  <div class="card">
    <div class="heart">💘</div>
    <h1>You've been invited!</h1>
    <p class="sub">Your special someone wants to pair with you on Lover's Compass — a compass that always points to them.</p>

    <div class="code" id="code">{safe_code}</div>
    <div class="copy-hint" id="copy-hint">tap the code to copy it</div>

    <button class="btn btn-primary" id="btn-open">Open in the App</button>
    {store_button}
    <a class="btn btn-tertiary" href="/?code={safe_code}">Continue in your browser</a>

    <p class="note">Don't have the app yet? You can use Lover's Compass right in your browser — no download needed.</p>
  </div>

<script>
(function () {{
  var code = "{safe_code}";
  var deepLink = "loverscompass://join/" + code;
  var storeUrl = "{store_url}";
  var isAndroid = /android/i.test(navigator.userAgent);
  var isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);

  // On Android there is no native app yet — send users straight to the web app.
  var btnOpen = document.getElementById("btn-open");
  if (isAndroid) {{
    btnOpen.textContent = "Open Lover's Compass";
    btnOpen.addEventListener("click", function () {{
      window.location.href = "/?code=" + code;
    }});
  }} else {{
    btnOpen.addEventListener("click", function () {{
      var start = Date.now();
      window.location.href = deepLink;
      // If the app isn't installed, nothing happens; fall back after a beat.
      setTimeout(function () {{
        if (document.hidden || Date.now() - start > 2500) return; // app opened
        if (storeUrl) {{
          window.location.href = storeUrl;
        }} else {{
          window.location.href = "/?code=" + code;
        }}
      }}, 1600);
    }});
  }}

  // Tap code to copy
  document.getElementById("code").addEventListener("click", function () {{
    if (navigator.clipboard) {{
      navigator.clipboard.writeText(code).then(function () {{
        document.getElementById("copy-hint").textContent = "copied! 💕";
      }});
    }}
  }});
}})();
</script>
</body>
</html>"""
