# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

# [2.4.0]

### Added
- Points system: registered users earn points for civic engagement
  - +10 points when a report submitted by the user is resolved by an authority
  - +2 points when another citizen confirms the user's report
  - +1 point when the user confirms someone else's report
  - -5 points (floor 0) when the user's report is rejected by an authority
- Points balance displayed on the profile screen with a trophy icon
- Points history screen: tap the points tile to see a full log of point changes (reason and date), newest first

### Tests
- Unit tests for `PointsService` covering all point award and deduction rules (18 tests)
- Integration tests for `PointsService` + `ReportService` interaction (7 tests)
- Acceptance tests for the points history screen (4 tests)

# [2.3.1]

### Fixed
- Notification bell reacts to auth state changes via stream instead of a one-time check
- Notification query avoids Firestore composite index requirement by sorting client-side

# [2.3.0]

### Added
- Notification system: bell icon with unread badge in Home and All Reports screens
- Notifications are created when an authority changes a report's status, sets its priority, confirms it, or rejects it
- Only the report owner and users who favourited the report receive notifications
- Notifications screen with relative timestamps and colour-coded icons by type
- "Mark all read" action and tap-to-mark-as-read on individual notifications
- Bell icon hidden for unauthenticated users and reacts in real time to login/logout

# [2.2.2]

### Fixed
- Guest users can now submit reports without being logged in
- Removed login requirement guard from report navigation
- Updated Firestore rules to allow unauthenticated report creation

# [2.2.1]

### Tests
- Added some integration_test.dart
- Added testing for photo upload

# [2.2.0]

### Added
- Functional photo upload for reports
- All reports now present a button that allows to visaulise the image

# [2.1.1]

### Tests
- report_service_test.dart (created)

## [2.1.0]

### Added

- added code to all_reports_screen.dart: if the user is an authority then it can reject reports or confirm them. Either way, regular users stop having the possibility of confirming/negating those reports. If authority confirms a report then a check will appear in the reports page, if it rejects them, they dissapear from the database   

## [2.0.0]

### Added

- Favourite reports: authenticated users can star reports in the All Reports screen
- Favourites persisted per-user in Firestore (`user_favourites` collection)
- "Favourites only" filter toggle in the filter sheet (authenticated users only)
- Unit, widget and acceptance tests for the favourite reports feature

### Fixed

- Star button uses `IconButton` to avoid gesture conflicts with the report card tap

## [1.9.0]
### Added
- Detail popup when tapping a map marker or an issue in the All Reports list, showing the street name, upload date, and number of confirmations/denials.

## [1.8.1]

### Added
- Sprint 2 Visual Documentation: Added screenshots demonstrating the progress and new features implemented during the second sprint.

- Sprint 2 Overview: Included descriptive texts detailing the goals achieved and improvements made during this development cycle.

## [1.8.0]

### Added
- Authority Status Management: Authorities can now change the status of reported issues

## [1.7.3] 

### Tests

- location_porto_test.dart
- priority_authority_test.dart (both created and without errors)


## [1.7.2] 

### Added

- authority users now have a page where it shows the reports in descending order of confirmations (by the users). They can also prioritise the report by marking it with a yellow star.

## [1.6.2] 

### Fixed 

- Application now starts in Porto
- For submitting the location of a certain report, the app asks if it can access the user's location, if it has permission centers around its location, otherwise, remains in Porto 

## [1.6.1] 

### Added

- Tests for checkReportExists, confirmProblem, hasUserConfirmed methods
- Tests for confirmation buttons UI (not logged in, report owner, already confirmed)

## [1.6.0] 

### Added

- Confirmation buttons (checkmark/cross) to verify problem exists
- Auto-delete reports when formula triggers: (exists × 1.25 + 5) < not_exists

## [1.5.1]

### Fixed

- Profile tests - edit screen takes firestore parameter

## [1.5.0]

### Added

- Profile name, birth date fields
- Profile edit option

## [1.4.1]

### Fixed

- Missing package dependencies

## [1.4.0]

### Added

- Reports displayed as markers on map

## [1.3.3]

### Fixed

- Screen reordering in main

## [1.3.2]

### Fixed

- Search bar not working

## [1.3.1]

### Fixed

- Sign out clears user data

## [1.3.0]

### Added

- Split auth screen into login/register/profile

## [1.2.1]

### Added

- Tests for main screen with search

## [1.2.0]

### Added

- Search bar widget on main screen

## [1.1.0]

### Added

- Authority user role - authorities can resolve reports

## [1.0.0] - 2026-04-22

### Added

- Report problem feature tests
- Map screen with access to profile
- Welcome screen tests
- Location picker screen tests

### Fixed

- Test organization
- Screen organization

### Removed

- .idea folder

## [0.5.0] - 2026-04-19

### Changed

- README updated (Sprint 1 section)

## [0.4.0] - 2026-04-17

### Added

- Reports database implementation

## [0.3.0] - 2026-04-16

### Added

- Report problem feature (production)
- Report service
- Domain modeling updated
- Image domain modeling

## [0.2.0] - 2026-04-15

### Added

- Login and register user story (production)
- Problems list
- Updated mockups
- Map marking for problem location

## [0.1.0] - 2026-04-14

### Added

- Tests for map and login/register prototypes

## [0.0.0] - 2026-04-09

### Added

- First prototype implementation
- Auth prototype
- Location service prototype
- Image picker and camera prototypes
- Report problem prototype
- Map prototype
- Login/register prototypes
- Problems list
