# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.1] - 2026-04-29

### Added

- Tests for checkReportExists, confirmProblem, hasUserConfirmed methods
- Tests for confirmation buttons UI (not logged in, report owner, already confirmed)

## [1.6.0] - 2026-04-28

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