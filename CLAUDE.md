# APWebAuthentication

A Swift package providing in-app OAuth authentication (OAuth1 + OAuth2) across social platforms (Twitter/X, Reddit, Pinterest, GitHub, Tumblr, TikTok, Twitch, Foursquare).

## Build & Test

```bash
swift build
swift test
```

- Swift tools version: 6.0
- Platform: iOS 18+
- Uses Swift Package Manager

## Project Structure

- `Sources/` - All library source code (flat structure with per-provider subdirectories)
- `Tests/` - Unit tests using XCTest
- Provider subdirectories: `Foursquare/`, `GitHub/`, `Pinterest/`, `PinterestWeb/`, `Reddit/`, `TikTokWeb/`, `Tumblr/`, `Twitch/`, `X/`
- `Models/` - Shared model types (`GenericUser`, `MediaItem`, `StoryItem`, `MediaComment`)
- `UI/` - Web-based authentication view controllers

## Key Dependencies

- Alamofire (networking)
- CryptoSwift (crypto operations)
- SwiftyJSON (JSON parsing)
- SnapKit (Auto Layout)
- APUserAgentGenerator (user-agent string generation)

## Code Conventions

- Swift 6 strict concurrency
- Each provider has its own API client, interceptor, and user model
- OAuth1 flow: `OAuth1Client` + `OAuth1Interceptor`
- OAuth2 flow: `OAuth2Client` + `OAuth2Interceptor`
- `APWebAuthSession` is the main entry point for authentication flows
- `AccountStore` / `AccountType` manage provider configuration
