//
//  AuthController.swift
//  ENdi
//
//  Created by Will Nixon on 5/19/21.
//

import FirebaseAuth
import Foundation

class Authentication: NSObject, ObservableObject {
  @Published var controller: Authenticator? {
    didSet {
      if var controller = controller {
        controller.delegate = self
      }
    }
  }
  @Published var authenticated: AuthState = .unauthenticated
  @Published var displayName: String?
  @Published var profilePic: Data?
  @Published var error: String? {
    didSet {
      if let error = error {
        if !error.isEmpty {
          showingAlert = true
        }
      }
    }
  }
  @Published var showingAlert = false

  override init() {
    super.init()
    if let providerData = Auth.auth().currentUser?.providerData {
      switch providerData[0].providerID {
      case "password":
        controller = EmailAuthController()
        break
      case "google.com":
        controller = GoogleAuthController()
        break
      case "apple.com":
        controller = AppleAuthController(appWindow: nil)
        break
      default:
        controller = nil
      }
      authenticated = .authenticated
    }
  }
}

extension Authentication {
  public func handleError(authError: NSError) {
    let code = authError.code
    var err: AuthError
    switch code {
    case 17007:
      err = .emailInUse
    case 17008:
      err = .invalidEmail
    case 17009:
      err = .invalidPassword
    case 17010:
      err = .tooManyRequests
    case 17011:
      err = .userNotFound
    case 17020:
      err = .connectivity
    case 17026:
      err = .weakPassword
    case 17034:
      err = .emailRequired
    default:
      err = .authError
    }
    error = err.rawValue
  }
}

extension Authentication: AuthenticatorDelegate {
  func authenticator(_ authenticator: Authenticator, didUpdateStateTo authState: AuthState) {
    authenticated = authState
  }

  func authenticator(_ authenticator: Authenticator, didUpdateUser user: AuthUser) {
    displayName = user.displayName
    profilePic = user.profilePic
  }

  func authenticator(_ authenticator: Authenticator, didErrorWith authError: NSError) {
    handleError(authError: authError)
  }

  func authenticator(_ authenticator: Authenticator, didErrorWith errorMessage: String) {
    error = errorMessage
  }
}
