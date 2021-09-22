//
//  AuthenticatorDelegate.swift
//  ENdi
//
//  Created by Will Nixon on 8/27/21.
//

import Foundation

public protocol AuthenticatorDelegate {
  func authenticator(_ authenticator: Authenticator, didUpdateStateTo authState: AuthState)
  func authenticator(_ authenticator: Authenticator, didUpdateUser user: AuthUser)
  func authenticator(_ authenticator: Authenticator, didErrorWith authError: NSError)
  func authenticator(_ authenticator: Authenticator, didErrorWith errorMessage: String)
}
