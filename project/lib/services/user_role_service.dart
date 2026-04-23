import 'package:firebase_auth/firebase_auth.dart';
import 'user_role.dart';

/// Reads the role that was set on the Firebase user via Custom Claims.
///
/// To grant the "authority" role to a user, set the custom claim in the
/// Firebase Admin SDK (e.g. a Cloud Function or Admin script):
///
///   admin.auth().setCustomUserClaims(uid, { role: 'authority' });
///
/// The claim becomes visible to the client after the user's ID token is
/// refreshed (at most ~1 hour, or force it with [refreshRole]).
class UserRoleService {
  const UserRoleService();

  /// Returns the [UserRole] for the currently signed-in user.
  /// Defaults to [UserRole.citizen] when no claim is present.
  Future<UserRole> getRole(User user) async {
    final idTokenResult = await user.getIdTokenResult();
    final claims = idTokenResult.claims ?? {};
    if (claims['role'] == 'authority') {
      return UserRole.authority;
    }
    return UserRole.citizen;
  }

  /// Forces a token refresh so newly-assigned claims are picked up immediately.
  Future<UserRole> refreshRole(User user) async {
    await user.getIdToken(true); // forceRefresh = true
    return getRole(user);
  }
}
