# APWebAuthentication

A Swift framework for in-app OAuth authentication across popular social platforms like Twitter, Reddit, Pinterest, and GitHub — with native-style login flows, retry logic, and token management.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Faporat%2FAPWebAuthentication%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/aporat/APWebAuthentication)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Faporat%2FAPWebAuthentication%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/aporat/APWebAuthentication)
![GitHub Actions Workflow Status](https://github.com/aporat/APWebAuthentication/actions/workflows/ci.yml/badge.svg)
[![codecov](https://codecov.io/github/aporat/APWebAuthentication/graph/badge.svg?token=OHF9AE0KMC)](https://codecov.io/github/aporat/APWebAuthentication)

---

## ✨ Features

- 🔐 OAuth1 + OAuth2 support
- 🌐 Safari-style login UI via `WKWebView`
- 🍪 Cookie/session handling
- 🔁 Smart retry & rate-limit UI
- 🧠 Customizable user-agent
- 💬 Built-in models for Reddit, Pinterest, Twitter, GitHub

---

## 🚀 Supported Providers

- Twitter
- Reddit
- Pinterest
- GitHub

Extendable via `OAuth1Client` / `OAuth2Client`.

---

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/aporat/APWebAuthentication.git", from: "1.0.0")
]
```

---

## 🧑‍💻 Usage

```swift
let auth = Auth2Authentication()
auth.accountIdentifier = "github"

let client = GitHubAPIClient(auth: auth)

let session = APWebAuthSession(accountType: AccountStore.github) { result in
    switch result {
    case .success(let params):
        print("Access token:", params?["access_token"] ?? "")
    case .failure(let error):
        print("Auth failed:", error.localizedDescription)
    }
}

session.presentationContextProvider = self
session.start(url: loginURL, callbackURL: redirectURL)
```

---

## 🛠 Architecture

- `APWebAuthSession` – UI + login flow
- `OAuth1Client`, `OAuth2Client` – Auth-aware clients
- `AuthClientRequestRetrier` – Retry logic & UI
- `BaseUser`, `MediaItem` – Common model interfaces
- `WebAuthViewController`, `WebTokenInterceptorViewController` – Web UI

---

## 🧪 Testing

Run:

```bash
swift test
```

Includes tests for:
- Token adapters & clients
- User & post parsing
- Rate-limit retry logic

---

## 📄 License

MIT

---

## 👤 Author

Built by [Aporat](https://github.com/aporat) • PRs welcome!
