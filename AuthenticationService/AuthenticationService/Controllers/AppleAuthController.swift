//
//  AppleAuthController.swift
//  ENdi
//
//  Created by Will Nixon on 7/26/21.
//

import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation

public class AppleAuthController: NSObject {
  fileprivate let appleError =
    "Sign in with Apple failed. If this problem persists, please contact us."
  fileprivate var currentNonce: String?
  fileprivate var window: UIWindow?

  public var user = AuthUser()
  public var delegate: AuthenticatorDelegate?
  public var credential: AuthCredential?

  public init(appWindow: UIWindow?) {
    super.init()
    if appWindow != nil {
      window = appWindow

      configure(Auth.auth().currentUser)

      Auth.auth().addStateDidChangeListener { [self] (auth, currentUser) in
        configure(Auth.auth().currentUser)
      }
    }
  }
}

extension AppleAuthController {
  public func startSignInFlow() {
    delegate?.authenticator(self, didUpdateStateTo: .authenticating)
    let nonce = randomNonceString()
    currentNonce = nonce
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = sha256(nonce)

    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    authorizationController.delegate = self
    authorizationController.presentationContextProvider = self
    authorizationController.performRequests()
  }
}

extension AppleAuthController: Authenticator {
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
    delegate?.authenticator(self, didUpdateStateTo: .unauthenticating)
    do {
      try Auth.auth().signOut()
      delegate?.authenticator(self, didUpdateStateTo: .unauthenticated)
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

extension AppleAuthController: ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding
{
  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor
  {
    return window!
  }

  private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
      Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
      let randoms: [UInt8] = (0..<16).map { _ in
        var random: UInt8 = 0
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
        if errorCode != errSecSuccess {
          #if DEBUG
            fatalError(
              "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
          #else
            self.delegate?.authenticator(
              self,
              didErrorWith:
                "Sign In with Apple unavailable. Please contact us if this issue persists."
            )
          #endif
        }
        return random
      }

      randoms.forEach { random in
        if remainingLength == 0 {
          return
        }

        if random < charset.count {
          result.append(charset[Int(random)])
          remainingLength -= 1
        }
      }
    }

    return result
  }

  private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
      return String(format: "%02x", $0)
    }.joined()

    return hashString
  }

  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
      guard let nonce = currentNonce else {
        #if DEBUG
          fatalError("Invalid state: A login callback was received, but no login request was sent.")
        #else
          self.delegate?.authenticator(self, didErrorWith: appleError)
          return
        #endif
      }
      guard let appleIDToken = appleIDCredential.identityToken else {
        print("Unable to fetch identity token")
        return
      }
      guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
        print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
        return
      }

      if let fullName = appleIDCredential.fullName {
        if let givenName = fullName.givenName {
          let displayName = givenName
          self.changeDisplayName(to: displayName)
        }
      }

      // Initialize a Firebase credential.
      credential = OAuthProvider.credential(
        withProviderID: "apple.com",
        idToken: idTokenString,
        rawNonce: nonce
      )
      // Sign in with Firebase.
      signIn()
    }
  }

  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    print("Sign in with Apple errored: \(error)")
    self.delegate?.authenticator(self, didErrorWith: appleError)
  }
}
