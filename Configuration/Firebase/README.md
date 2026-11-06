# Firebase Analytics configuration

Only Firebase Analytics is linked. Do not add Firebase Authentication,
Crashlytics, Cloud Messaging, Remote Config, or other Firebase products without
a separate review.

Supply these uncommitted files:

- `Configuration/Firebase/Dev/GoogleService-Info.plist` for Development,
  Staging, and Demo.
- `Configuration/Firebase/Prod/GoogleService-Info.plist` for Production.

Both Firebase app registrations must use the bundle identifier
`com.kairoid.Kairo`. A build phase copies the selected file to the app bundle as
`GoogleService-Info.plist` and fails if the selected file is missing.

The analytics wrapper accepts only fixed event names and no event parameters.
Its only supported identity is the authenticated account's opaque internal
UUID. Names, emails, phone numbers, government identifiers, document IDs, and
free-form text must never be sent to Firebase.

Firebase records `app_open` automatically. KairoID emits these parameterless
events after the corresponding successful product action: `sign_up`,
`profile_created`, `verification_started`, `verification_completed`,
`trust_score_viewed`, and `share_link_created`.

`IS_ANALYTICS_ENABLED` in the downloaded Firebase plist is a legacy unread
field in Firebase 13.1.1. KairoID explicitly grants analytics storage and
enables collection after configuring Firebase. Advertising storage, advertising
user data, and ad personalization remain denied. The IDFA-free
`FirebaseAnalyticsCore` product is linked, IDFV collection and automatic screen
reporting are disabled, and no analytics-specific user-consent toggle currently
exists. Trust Score, DigiLocker, verification, and sharing consent govern
different product purposes and do not toggle analytics collection.
