# Solana Insider Watch Mobile (PWA)

An iPhone/Android installable web app that monitors public Solana market signals using DEX Screener.

## Included
- Four existing Solana watchlist addresses preloaded
- BUY WATCH / NEUTRAL / HIGH RISK scoring
- price, market cap, liquidity, 5-minute buys/sells and volume
- liquidity-change detection using local history
- 60-second refresh while the app is open
- editable watchlist stored on the phone
- foreground/local notifications when status changes and permission is granted
- Home Screen PWA manifest and offline shell

## Install on iPhone
A PWA must be served over HTTPS (or localhost) for full installation/service-worker behavior. Upload this folder to any static HTTPS host such as GitHub Pages, Cloudflare Pages, Netlify, or Vercel. Then:
1. Open the HTTPS address in Safari.
2. Tap Share.
3. Tap **Add to Home Screen**.
4. Open **Insider Watch** from the new Home Screen icon.

## Background alerts
This static version cannot reliably continue 60-second polling after iOS suspends the app. True background push alerts require a hosted backend/push service. The existing Python monitor can be used as that backend, or a serverless worker can be added later.

## Security
No wallet private key or seed phrase is used or requested. This app is read-only and does not place trades.
