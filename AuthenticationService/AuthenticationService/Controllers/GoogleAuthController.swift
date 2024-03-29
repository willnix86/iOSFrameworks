//
//  AuthController2.swift
//  ENdi
//
//  Created by Will Nixon on 7/26/21.
//

import Firebase
import FirebaseAuth
import Foundation
import GoogleSignIn

public class GoogleAuthController: NSObject {
  public var user = AuthUser()
  public var delegate: AuthenticatorDelegate?
  public var credential: AuthCredential?
  public var clientID: String? {
    return FirebaseApp.app()?.options.clientID
  }

  public override init() {
    super.init()
    configure(Auth.auth().currentUser)

    Auth.auth().addStateDidChangeListener { [self] (auth, currentUser) in
      configure(Auth.auth().currentUser)
    }
  }
}

extension GoogleAuthController {
  public func startSignInFlow(using viewController: UIViewController?) {
    if viewController != nil {
      delegate?.authenticator(self, didUpdateStateTo: .authenticating)
      guard self.clientID != nil else { return }
      
      let config = GIDConfiguration(clientID: self.clientID!)
      
      GIDSignIn.sharedInstance.signIn(with: config, presenting: viewController!) { [unowned self] user, error in
        if let error = error {
          delegate?.authenticator(self, didErrorWith: error.localizedDescription)
          return
        }
        
        guard
          let authentication = user?.authentication,
          let idToken = authentication.idToken
        else {
          return
        }
        
        self.credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: authentication.accessToken)
        
        self.signIn()
      }
    }
  }
}

extension GoogleAuthController: Authenticator {
  public func signIn() {
    if let credential = credential {
      Auth.auth().signIn(with: credential) { [self] (authResult, authError) in
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
      if let googleUser = GIDSignIn.sharedInstance.currentUser {
        if let profile = googleUser.profile {
          if let name = profile.givenName {
            self.changeDisplayName(to: name)
          } else {
            if let displayName = currentUser.displayName {
              self.changeDisplayName(to: displayName)
            }
          }
          if let url = profile.imageURL(withDimension: 500) {
            changeProfilePicURL(to: url)
          } else {
            if let url = currentUser.photoURL {
              changeProfilePicURL(to: url)
            }
          }
        }
      } else {
        if let displayName = currentUser.displayName {
          self.changeDisplayName(to: displayName)
        }
        if let url = currentUser.photoURL {
          changeProfilePicURL(to: url)
        }
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
        user.setDisplayName(displayName: givenName)
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

//extension GoogleAuthController: GIDSignInDelegate {
//  public func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error?)
//  {
//    if error != nil {
//      delegate?.authenticator(self, didErrorWith: error!.localizedDescription)
//      return
//    }
//
//    guard let authentication = user.authentication else { return }
//    credential = GoogleAuthProvider.credential(
//      withIDToken: authentication.idToken,
//      accessToken: authentication.accessToken
//    )
//    self.signIn()
//  }
//
//  public func sign(
//    _ signIn: GIDSignIn!,
//    didDisconnectWith user: GIDGoogleUser!,
//    withError error: Error!
//  ) {
//    signOut()
//  }
//}
