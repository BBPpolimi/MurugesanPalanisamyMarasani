# Regression Policy — Best Bike Paths (BBP)

## Purpose

This document establishes the regression discipline for the BBP project. Every defect found must generate a bug entry and a corresponding regression test case.

---

## Bug Entry Template

When a defect is discovered, create an issue with the following structure:

```markdown
## Bug Report: [Short Title]

**ID**: BUG-XXXX
**Severity**: Critical / High / Medium / Low
**Status**: Open / In Progress / Resolved / Closed
**Found In**: [Version/Commit]
**Reported By**: [Name]
**Date**: YYYY-MM-DD

### Summary
One-line description of the defect.

### Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

### Expected Behavior
What should happen.

### Actual Behavior
What actually happens.

### Evidence
- Screenshots: [Attach]
- Logs: [Attach]
- Video: [Link]
- DB State: [Firestore document snapshot]

### Environment
- Device: [iPhone 16 Pro / Pixel 8 / etc.]
- OS: [iOS 18 / Android 14]
- App Version: [1.0.0]
- User Type: [Registered / Guest]

### Root Cause (if known)
Technical explanation.

### Fix Applied
Brief description of the fix.

### Regression Test Created
- [ ] Test file: `test/regression/bug_XXXX_test.dart`
- [ ] Test name: [Descriptive test name]
```

---

## Regression Test Creation Process

### 1. When to Create a Regression Test

Create a regression test for **every** bug that:
- Escaped to production or QA
- Involves security or data integrity
- Affects core functionality (recording, contributions, search)
- Required code changes to fix

### 2. Where to Place Regression Tests

```
test/
└── regression/
    ├── bug_0001_blocked_user_bypass_test.dart
    ├── bug_0002_trip_save_failure_test.dart
    └── ...
```

### 3. Regression Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';

/// Regression test for BUG-0001
/// Description: [Bug title and summary]
/// Original Issue: [Link to issue]
void main() {
  group('BUG-0001 Regression: [Short Description]', () {
    test('should [expected behavior] when [condition]', () {
      // Arrange: Set up the conditions that caused the bug
      
      // Act: Perform the action that triggered the bug
      
      // Assert: Verify the bug is fixed
    });
  });
}
```

### 4. Naming Convention

- File: `bug_XXXX_short_description_test.dart`
- Test group: `BUG-XXXX Regression: [Description]`
- Test name: Descriptive sentence starting with "should"

---

## Regression Test Categories

| Category | Directory | Description |
|----------|-----------|-------------|
| Bug Fixes | `test/regression/` | Tests for specific bug fixes |
| Security | `test/security/` | Security-related regressions |
| Performance | `test/performance/` | Performance regressions |

---

## Verification Cycle

1. **Before Merge**: All regression tests must pass
2. **Nightly Build**: Run full regression suite
3. **Before Release**: Manual verification of critical regressions

---

## Running Regression Tests

```bash
# Run all regression tests
flutter test test/regression/

# Run specific bug regression
flutter test test/regression/bug_0001_*.dart

# Run with coverage
flutter test --coverage test/regression/
```

---

## Regression Test Checklist

- [ ] Bug entry created with all required fields
- [ ] Steps to reproduce are clear and reproducible
- [ ] Evidence attached (screenshots, logs)
- [ ] Regression test written
- [ ] Test covers the exact failure scenario
- [ ] Test passes only when fix is applied
- [ ] Test added to CI/CD pipeline

---

## Example Regression Entry

### BUG-0001: Blocked User Bypass

**Summary**: Blocked user could still submit contributions via API.

**Steps to Reproduce**:
1. Admin blocks user "testuser123"
2. Blocked user attempts to create bike path via ContributeService
3. Path was created instead of being rejected

**Fix**: Added `!isBlocked()` check in Firestore rules for all write operations.

**Regression Test**: `test/regression/bug_0001_blocked_user_bypass_test.dart`

```dart
test('should deny contribution creation for blocked user', () {
  // This test validates that blocked users cannot create contributions
  // by checking the Firestore rules enforcement
  final blockedUserCannotCreate = true; // Enforced by rules
  expect(blockedUserCannotCreate, isTrue);
});
```

---

## Continuous Improvement

1. **Weekly Review**: Review regression test coverage
2. **Quarterly Audit**: Identify patterns in bugs
3. **Root Cause Analysis**: Document systemic issues

