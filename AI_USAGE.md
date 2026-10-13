# AI Usage

I used AI throughout this assignment, mainly for **planning, research and productivity**, and to catch up on what changed in iOS since I last worked in Swift (September 2025). Claude (chat) helped with planning; Claude Code did most of the implementation under my direction. The decisions are mine, and this log focuses on them: what came up, what I decided, and why.

Prompts are quoted close to how I wrote them, lightly edited for readability.

---

## 1. Planning

**Prompt** *(with the brief attached)*
> "Set up all the steps we need, from Xcode project and git setup through to where we can move over to Claude Code. I usually use the MVVM pattern."

| Topic | Options considered | Decision and why |
|---|---|---|
| Architecture | MVVM | **MVVM**: what I know best, and it maps cleanly to the list, map and settings features. Protocols and one composition root keep the view models testable. |
| Mock REST | Decode bundled JSON directly, or a `URLProtocol` stub | **`URLProtocol` stub**, so the real `URLSession` client, auth header, status codes and error mapping all run. Only the server is fake. |
| Places feature | Place search, or address → coordinates | **Address → coordinates**: a protocol-backed service that is testable and mockable, and a natural place to show concurrency (`TaskGroup`) and caching. |
| Secrets | — | Google key in a gitignored `.xcconfig`, never in the repo, because the repo is public. |

Research that shaped the plan: the Google Maps/Places SDKs (10+) need Xcode 26 or later, and the Maps SDK follows system dark mode by itself, which covers the live light/dark requirement for the map.

---

## 2. Deployment target and state management

**Prompt**
> "We're still doing MVVM, right? I'm not sure I understand '@Observable needs iOS 17'. I last worked on iOS in September 2025, so I don't know how much changed."

- **First decision: `ObservableObject` with `@Published`.** I wanted to use `@Observable`, but the brief says iOS 16, and a backport library would add a dependency just to work around a constraint.
- **What changed:** Xcode 27 can't target iOS 16 at all. Installing an older Xcode only to reach 16 wasn't worth it, so the target became **iOS 17.0**, documented as a deviation in `SOLUTION.md`.
- **Reversed decision: `@Observable`.** The iOS 16 target was the only reason against Observation. Once it was gone, keeping the older pattern would have been legacy by choice.

---

## 3. Concurrency model

**Prompt**
> "Why are we using `nonisolated`, and also `final`, on these types?"

I asked the AI to justify these rather than accept them. The answer changed how I read the code:
- New Xcode projects default to **MainActor isolation**, so UI code is safe by default and anything that works in the background (models, networking, Keychain, geocoding) has to opt out with `nonisolated`, or be an `actor`.
- `final` lets the compiler prove a class is `Sendable`, since no subclass can add unsafe state.

**What I learned:** the default has flipped. Instead of marking UI code `@MainActor`, you now mark background code as the exception.

---

## 4. Secrets and the API key

**Prompt**
> "Will rotating the key make a difference?"

- **Caught the real key in a tracked config file before it was committed** and moved it to the gitignored `Secrets.xcconfig`. The committed `App.xcconfig` defaults the key to empty with an optional include, so a fresh clone builds without one.
- **Restricted rather than rotated.** The key never reached a remote, and a Maps key ships inside the app binary anyway, so the real protection is in Google Cloud: this bundle ID only, and only Maps SDK for iOS and Places API (New).

---



## 5. What verification caught

Each of these passed the compiler and every unit test:
- **CI signing:** the first CI draft disabled code signing, which removes the app's Keychain access (`-34018`), so four Keychain tests failed. Running the exact CI command locally exposed it before it reached GitHub.
- **"10 venders":** SwiftUI's automatic plural inflection doesn't know the word "vendor". Caught from a screenshot and replaced with explicit wording.
- **A force unwrap** in the stub's base URL went against the project's own convention, and was removed.

And one that only real CI could catch:
- **Project format:** the first GitHub Actions run failed because Xcode 27 saves the project in a newer file format (110) that the runner's Xcode 26.6 can't open. Nothing in the project needed Xcode 27, so I set the project file back to the Xcode 16 format, confirmed all tests still passed locally, and pushed. CI went green, and the README now states Xcode 26 or later.

**What I learned:** run the CI command locally before trusting the workflow, but still let real CI run on a clean machine, because my machine had a newer Xcode than the runner. And look at the screens, not just the test results.
