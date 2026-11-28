# Anonymous usage statistics

AlienMatch sends a small set of anonymous usage events through the shared
`ol1n_telemetry` package (<https://github.com/lioilsources/Ol1nTelemetry>),
so the owner can see where new people drop off on the way to a finished
profile, which screens and features are used, and where flows fail. This file
is the **event dictionary**: the constant `appDictionary`
(`app/lib/telemetry/telemetry_dictionary.dart`) and this document list
exactly the same events and properties, and `app/test/telemetry_test.dart`
fails when they drift apart.

Adding an event or a property is a change to the privacy policy
(`docs/privacy.html`) and to the store privacy answers. Ask the owner first.

## Rules

The rules of `ol1n_telemetry` apply unchanged: no persistent identifier (a
random session id in memory only), cohorts computed on the device, only
enums, bands and numbers, no key → no network, off wipes the queue at once,
measuring never steers the app. On the web nothing is recorded at all.

On top of that, for AlienMatch:

- **Not linked to the account.** The statistics never go through the
  AlienMatch API and never carry the account token or its hash, a user,
  photo, wall or place id, the nickname, region, generation, status, kids,
  intents, beacon or encouragement settings, the mood consent, mood levels
  or trends, check-in modes or ratings, star ratings, or anything else from
  the profile, the walls or the check-ins. Only screens, features and flow
  results. A test in `app/test/telemetry_test.dart` rejects property names
  that look like any of these.
- **Separate receiver.** Events go only to the developer's own collector
  (StoreMetrics, protocol v1), on a different host and with a different key
  than the AlienMatch API; the two databases are not joined.
- `hadDataBefore` only checks whether an account token already exists on
  the phone, so existing users count as `pre` rather than new installs. The
  token itself is never read into the statistics.

## Configuration

| `--dart-define` | Meaning |
|---|---|
| `TELEMETRY_KEY` | AlienMatch's key at the collector (`alienmatch` in StoreMetrics). Empty → nothing is sent. |
| `TELEMETRY_HOST` | The collector's base address. Must be `https`. Empty → nothing is sent. |
| `TELEMETRY_DEBUG` | `true` prints events to the console instead of sending them. |

`release-android.yml` and `release-ios.yml` pass both from the GitHub secrets
of the same names. An absent secret expands to an empty string and the build
is silent; such a build also hides the "Anonymous statistics" switch in
settings. The key and the collector's address never go into this repository.

## Activation

The first finished profile: profile steps saved and the first photo uploaded
during onboarding (`AppState.useFace`), i.e. the user reaches the radar. A
first match was considered, but it depends on other people and on the mood
matrix, so it would measure the community, not the app; match outcomes are
in `wave_send.result` instead.

## Features

`filter` (a mirror filter picked in the camera), `album` ("My faces" opened),
`face_switch` (another face made the profile photo), `stars_rate` (a star
liked or disliked), `liked` (liked faces opened), `places_search` (catalog
search), `sticker_ink` (hand-drawn sticker), `sticker_preset` (preset
sticker), `flyby` (fly-bys switched on), `report` (a sticker reported).

## Screens

Root route: `loading`, `welcome`, `onboarding`, `capture`, `radar`, `walls`,
`checkin`, `places`, `settings` (reported by the widgets through
`AppScreens.root`). Pushed routes by name: `/wall` → `wall`, `/ink` → `ink`,
`/faces` → `faces`, `/capture` → `capture`, `/stars` → `stars`, `/liked` →
`liked`. Dialogs and sheets do not change the screen.

## Common properties

Sent with every event.

| Property | Type | Values |
|---|---|---|
| `app_version` | enum | the app version (`kAppVersion`, checked against `pubspec.yaml`) |
| `platform` | enum | `ios`, `android`, `macos`, `windows`, `linux`, `other` |
| `lang` | enum | the app's language: `cs`, `de`, `en`, `es`, `fr`, `it`, `pl`, `pt`, `sk`, `uk` |
| `session_band` | band | session number: `1`, `2`, `3-5`, `6-10`, `11+` |
| `days_band` | band | days since measuring began: `0`, `1`, `2-6`, `7-29`, `30+`, `pre` |
| `first_session` | bool | the very first session of a new install |
| `tester` | bool | tester build or tester device |

## Events

### `app_open`

Cold start, or a new session after more than 30 minutes in the background. *Answers: how many installs come back for a 2nd, 3rd, 6th and 11th session, and on day 1, 2, 7 and 30.*

| Property | Type | Values |
|---|---|---|
| `start` | enum | `cold`, `resume` |
| `session_band_first` | bool | yes/no |
| `days_band_first` | bool | yes/no |
| `campaign` | campaign | optional, `^[a-z0-9-]{1,24}$` |

### `screen_view`

A screen appeared. Root screens are the start-up stages (`loading`, `welcome`, `onboarding` = the profile steps, `capture` = the profile photo) and the five home tabs; the rest are pushed screens. *Answers: what a new user does after the first launch.*

| Property | Type | Values |
|---|---|---|
| `screen` | enum | `loading`, `welcome`, `onboarding`, `capture`, `radar`, `walls`, `checkin`, `places`, `settings`, `wall`, `ink`, `faces`, `stars`, `liked`, `other` |
| `prev` | enum | `loading`, `welcome`, `onboarding`, `capture`, `radar`, `walls`, `checkin`, `places`, `settings`, `wall`, `ink`, `faces`, `stars`, `liked`, `other`, `none` |

### `screen_leave`

A screen was left. *Answers: how long people stay on each screen, and where they stay long without doing anything.*

| Property | Type | Values |
|---|---|---|
| `screen` | enum | `loading`, `welcome`, `onboarding`, `capture`, `radar`, `walls`, `checkin`, `places`, `settings`, `wall`, `ink`, `faces`, `stars`, `liked`, `other` |
| `secs` | int | 0–86400 |
| `actions` | int | 0–100000 |

### `session_pause`

The app went to the background or is closing. Sent at once. *Answers: when and where people stop.*

| Property | Type | Values |
|---|---|---|
| `active_secs` | int | 0–86400 |
| `screen` | enum | `loading`, `welcome`, `onboarding`, `capture`, `radar`, `walls`, `checkin`, `places`, `settings`, `wall`, `ink`, `faces`, `stars`, `liked`, `other`, `none` |
| `screen_secs` | int | 0–86400 |

### `activation`

The first finished profile on this install: the profile steps saved and the first photo uploaded during onboarding, so the user lands on the radar. Once per install. *Answers: how many new installs get to the first real value, and how fast.*

| Property | Type | Values |
|---|---|---|
| `secs` | int | 0–86400 |

### `feature_use`

The first use of a feature in a session. *Answers: which features advanced users actually use.*

| Property | Type | Values |
|---|---|---|
| `feature` | enum | `filter`, `album`, `face_switch`, `stars_rate`, `liked`, `places_search`, `sticker_ink`, `sticker_preset`, `flyby`, `report` |

### `feature_snapshot`

After `app_open` of the 3rd, 6th and 11th session: which features this install has ever used. *Answers: what advanced users never use.*

| Property | Type | Values |
|---|---|---|
| `f_filter` | bool | yes/no |
| `f_album` | bool | yes/no |
| `f_face_switch` | bool | yes/no |
| `f_stars_rate` | bool | yes/no |
| `f_liked` | bool | yes/no |
| `f_places_search` | bool | yes/no |
| `f_sticker_ink` | bool | yes/no |
| `f_sticker_preset` | bool | yes/no |
| `f_flyby` | bool | yes/no |
| `f_report` | bool | yes/no |
| `features_used` | int | 0–10 |

### `error_shown`

The user saw an error. `network`: an API call failed (start-up, account, profile, radar, album, fly-by); `camera`: the camera could not open or the shot failed; `permission`: no camera or microphone permission for a check-in recording; `album_full`: no room for another face. *Answers: where people struggle.*

| Property | Type | Values |
|---|---|---|
| `kind` | enum | `network`, `camera`, `permission`, `album_full` |
| `screen` | enum | `loading`, `welcome`, `onboarding`, `capture`, `radar`, `walls`, `checkin`, `places`, `settings`, `wall`, `ink`, `faces`, `stars`, `liked`, `other`, `none` |

### `account_create`

The 18+ welcome screen tried to create the anonymous account. Never the mood consent, the token or anything else about the account. *Answers: how many first launches get past the welcome screen.*

| Property | Type | Values |
|---|---|---|
| `result` | enum | `ok`, `error` |

### `onboarding_start`

The wordless profile steps began (only for an account without a profile).

| Property | Type | Values |
|---|---|---|

### `onboarding_end`

The profile steps ended. `step` is the step reached (1–7), never what was picked; `ok` when the profile was saved. *Answers: at which profile step new users give up, and how long the steps take.*

| Property | Type | Values |
|---|---|---|
| `result` | enum | `ok`, `cancel`, `error`, `background` |
| `secs` | int | 0–86400 |
| `step` | int | 0–7 |

### `photo_start`

The live camera for the profile photo opened, during onboarding or from "My faces".

| Property | Type | Values |
|---|---|---|
| `source` | enum | `onboarding`, `album` |

### `photo_end`

The camera was left: `ok` when a face became the profile photo, `cancel` otherwise. Never which filter, side or face. *Answers: whether people get through the live photo, and how long it takes.*

| Property | Type | Values |
|---|---|---|
| `result` | enum | `ok`, `cancel`, `error`, `background` |
| `secs` | int | 0–86400 |

### `wave_send`

A wave was sent from the radar, the liked faces or a fly-by. `match`: mutual, a wall opened; `sent`; `limit`: the daily limit; `error`. Never at whom, which wall or what kind of match. *Answers: how often waving turns into a match, and how often people hit the limit or an error.*

| Property | Type | Values |
|---|---|---|
| `source` | enum | `radar`, `liked`, `flyby` |
| `result` | enum | `match`, `sent`, `limit`, `error` |

### `checkin_send`

A daily signal (check-in) was sent. Never the mode (video, voice or rating only), the rating, the mood level or the support card. *Answers: whether people keep sending the daily signal, and how often it fails.*

| Property | Type | Values |
|---|---|---|
| `result` | enum | `ok`, `error` |

### `places_save`

"My stars" (places) were saved. Never which places or how many. *Answers: whether people set up places, and how often saving fails.*

| Property | Type | Values |
|---|---|---|
| `result` | enum | `ok`, `error` |

### `account_delete`

Account deletion in settings: confirmed and done (`ok`), dismissed (`cancel`) or failed (`error`). *Answers: when people leave for good.*

| Property | Type | Values |
|---|---|---|
| `result` | enum | `ok`, `cancel`, `error` |
