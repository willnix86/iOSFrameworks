//
//  EmailAuthController.swift
//  ENdi
//
//  Created by Will Nixon on 7/26/21.
//

import FirebaseAuth
import SwiftUI

public class EmailAuthController: NSObject {
  public var delegate: AuthenticatorDelegate?
  public var user = AuthUser()
  public var firstname: String?
  public var email: String?
  public var password: String?

  public override init() {
    super.init()

    configure(Auth.auth().currentUser)

    Auth.auth().addStateDidChangeListener { [self] (auth, currentUser) in
      configure(Auth.auth().currentUser)
    }
  }
}

extension EmailAuthController {
  public func startSignInFlow(
    _email: String,
    _password: String,
    displayName: String,
    isNewUser: Bool
  ) {
    delegate?.authenticator(self, didUpdateStateTo: .authenticating)
    email = _email
    password = _password
    firstname = displayName
    if isNewUser {
      createUser(with: email!, password: password!, displayName: firstname!)
    } else {
      signIn()
    }
  }

  public func createUser(with email: String, password: String, displayName: String) {
    Auth.auth().createUser(withEmail: email, password: password) { [self] authResult, authError in
      if let error = authError as NSError? {
        delegate?.authenticator(self, didUpdateStateTo: .unauthenticated)
        delegate?.authenticator(self, didErrorWith: error)
        return
      }
    }
  }

  public func resetPassword(for email: String) {
    Auth.auth().sendPasswordReset(withEmail: email) { [self] authError in
      if let error = authError as NSError? {
        delegate?.authenticator(self, didErrorWith: error)
      } else {
        delegate?.authenticator(self, didErrorWith: AuthError.passwordReset.rawValue)
      }
    }
  }
}

extension EmailAuthController: Authenticator {
  public func signIn() {
    if let email = email, let password = password {
      Auth.auth().signIn(withEmail: email, password: password) { [self] authResult, authError in
        if let error = authError as NSError? {
          delegate?.authenticator(self, didUpdateStateTo: .unauthenticated)
          delegate?.authenticator(self, didErrorWith: error)
        }
      }
    }
  }

  public func signOut() {
    do {
      try Auth.auth().signOut()
    } catch {
      delegate?.authenticator(self, didErrorWith: AuthError.signOutError.rawValue)
    }
  }

  public func configure(_ user: User?) {
    if let currentUser = user {
      self.user.setUserID(id: currentUser.uid)
      if let displayName = currentUser.displayName {
        changeDisplayName(to: displayName)
      }
      if let url = currentUser.photoURL {
        changeProfilePicURL(to: url)
      }
      delegate?.authenticator(self, didUpdateStateTo: .authenticated)
    } else {
      delegate?.authenticator(self, didUpdateStateTo: .unauthenticated)
    }
  }

  public func changeDisplayName(to displayName: String) {
    let givenName = String(displayName.split(separator: " ")[0])
    if let currentUser = Auth.auth().currentUser {
      if currentUser.displayName != givenName
        || (user.displayName == nil || user.displayName!.isEmpty)
      {
        user.setDisplayName(displayName: givenName)
        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = givenName
        changeRequest.commitChanges { error in
          if error != nil {
            print(
              "Successfully updated display name for user [\(currentUser.uid)] to [\(displayName)]"
            )
          }
        }
      } else {
        user.setDisplayName(displayName: displayName)
      }
      delegate?.authenticator(self, didUpdateUser: user)
    }
  }

  public func changeProfilePicURL(to url: URL?) {
    if let currentUser = Auth.auth().currentUser {
      if let url = url {
        if currentUser.photoURL != url || user.profilePic == nil || user.profilePic!.isEmpty {
          let changeRequest = currentUser.createProfileChangeRequest()
          changeRequest.photoURL = url
          user.downloadProfilePic(from: url) {
            self.delegate?.authenticator(self, didUpdateUser: self.user)
          }
          changeRequest.commitChanges { error in
            if error != nil {
              print(
                "Successfully updated profile url for user [\(currentUser.uid)] to [\(url)]"
              )
            }
          }
        } else {
          user.downloadProfilePic(from: url) {
            self.delegate?.authenticator(self, didUpdateUser: self.user)
          }
        }
      }
    }
  }

  public func changeProfilePicData(to data: Data) {
    user.setProfilePic(data: data)
    delegate?.authenticator(self, didUpdateUser: user)
  }
}
