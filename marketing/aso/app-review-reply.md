# Reply to App Review (submission 55ab6665-381c-458b-87fb-c2faa0b65abd)

Draft. Fill in the [BRACKETS] with what really happened before sending. Every other sentence below is true as written; don't add claims we can't back up.

---

Hello,

Thank you for the review. We took the feedback seriously and rebuilt the app before resubmitting (build 1.0 (3)). Here are the changes, followed by answers to your questions.

**What changed**
- The app is now focused on one audience: people who find small physical remotes and small, icon-only remote apps hard to use.
- A new default "Big Buttons" layout shows the most-used controls as large keys with word labels, in three sizes.
- New High Contrast mode and Speak Button Names (spoken feedback that stays silent when VoiceOver is on).
- Siri and Shortcuts support: seven App Intents with spoken phrases (turn off, mute, volume up and down, press any button, open a TV app, run a routine).
- Routines: user-built sequences of button presses, app launches, waits and typed text, run in one tap or by voice.
- A brand-first name ("Zapply: Big Button TV Remote"), no subscription screen at launch, and a single yearly plan instead of weekly and yearly.

**1. What the app does and the problem it solves**
Zapply lets someone control a Roku, Samsung (Tizen) or LG (webOS) TV from their iPhone over their home Wi-Fi, without any extra hardware. The problem it targets is that physical remotes and most phone remotes have small, unlabeled buttons, which are hard to read and press for people with low vision, tremor or limited dexterity, and confusing for less technical users. Zapply shows fewer, larger buttons with words on them, lets the user pick the size and a high-contrast look, can read each button aloud, and lets common tasks be done by voice through Siri or with one tap through routines (for example "mute, wait, switch off" at bedtime).

**2. Intended users**
Older adults; people with low vision, tremor, arthritis or other limited dexterity; people who rely on VoiceOver or voice commands; and family members or caregivers who set up routines for them. It's also useful to anyone who has misplaced the physical remote.

**3. What it does that existing apps don't, or do less well**
Most remote apps in this category use small, icon-only buttons modeled on physical remotes, and many open with a subscription screen before the remote can be used. Zapply is designed around readability and simplicity first: word-labeled keys in three sizes, a high-contrast mode, spoken button names, full VoiceOver labels, Siri voice commands that work without opening the app, and routines that turn multi-step tasks into one tap or one sentence. A built-in Demo TV lets people practise every button before using their real TV. The app has no ads, no accounts and no tracking, and it doesn't ask for payment at launch.

**4. Beta testing and feedback applied**
Before the first submission, testing was done by the developer: in the iOS Simulator, against a virtual Demo TV built into the app, and through TestFlight internal testing. Since the review, [DESCRIBE THE REAL TESTING: for example, "we tested build 3 on our own Samsung TV and gave it to two family members aged 70+ via TestFlight"]. Feedback we applied: [LIST REAL FEEDBACK AND THE CHANGE IT LED TO, or delete this sentence if there isn't any yet].

**5. Standalone or part of a suite**
Zapply is a standalone product. Our developer account also publishes unrelated apps in other categories (for example a vehicle history lookup, a private photo vault and a calorie tracker). None of them is a TV remote or controls TVs, and none overlaps with Zapply's purpose.

**6. Could it be an in-app purchase or feature in another of our apps?**
No. None of our other apps controls devices or relates to TVs, so this functionality wouldn't fit any of them.

**7. Shared code, frameworks or assets with our other apps**
No. Zapply's code, interface and assets were written for this app. It uses only Apple's frameworks (SwiftUI, StoreKit, App Intents, Foundation, AVFoundation) and no third-party frameworks or SDKs.

**8. Shared code with third-party apps**
No shared codebase, SDK or content library. The app talks to TVs using the control interfaces the TV makers provide on the local network (Roku's documented External Control Protocol, and the WebSocket interfaces Samsung and LG TVs expose to remote apps). For LG pairing, the list of permission names the app requests matches the one used by the open-source aiowebostv library (Apache 2.0); no code from it is included.

**9. Client, partner or third party**
No. Zapply is our own product, concept and brand, built and submitted by us. It isn't made from a commercial template or an app-generation service. [OPTIONAL, IF YOU WANT TO BE FULLY TRANSPARENT: "We used AI coding assistance while writing it."]

Thank you for taking another look.

---

Notes before sending:
- Send this as a reply on the App Review page in App Store Connect (submission 55ab6665…), then resubmit build 3. Or include the "What changed" part in the review notes, which is already done.
- Question 4 is where reviewers look for real evidence. Please try build 3 from TestFlight on your own TV first, and ideally give it to one or two people from the target audience.
