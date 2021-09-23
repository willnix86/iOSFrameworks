//
//  AuthController.swift
//  ENdi
//
//  Created by Will Nixon on 5/19/21.
//

import FirebaseAuth
import Foundation
import Firebase
import GoogleSignIn

public class Authentication: NSObject, ObservableObject {
  public static func setupApp() {
    FirebaseApp.configure()
  }
  
  public static func handleGoogleSignin(_ url: URL) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
  }
  
  @Published public var controller: Authenticator? {
    didSet {
      if var controller = controller {
        controller.delegate = self
      }
    }
  }
  @Published public var authenticated: AuthState = .unauthenticated
  @Published public var displayName: String?
  @Published public var profilePic: Data?
  @Published public var error: String? {
    didSet {
      if let error = error {
        if !error.isEmpty {
          showingAlert = true
        }
      }
    }
  }
  @Published public var showingAlert = false

  public override init() {
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
  public func authenticator(_ authenticator: Authenticator, didUpdateStateTo authState: AuthState) {
    authenticated = authState
  }

  public func authenticator(_ authenticator: Authenticator, didUpdateUser user: AuthUser) {
    displayName = user.displayName
    profilePic = user.profilePic
  }

  public func authenticator(_ authenticator: Authenticator, didErrorWith authError: NSError) {
    handleError(authError: authError)
  }

  public func authenticator(_ authenticator: Authenticator, didErrorWith errorMessage: String) {
    error = errorMessage
  }
}
