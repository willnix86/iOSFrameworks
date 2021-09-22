//
//  Authenticator.swift
//  ENdi
//
//  Created by Will Nixon on 7/26/21.
//

import FirebaseAuth
import Foundation
import SwiftUI

public protocol Authenticator {
  var delegate: AuthenticatorDelegate? { get set }
  var user: AuthUser { get set }

  func signIn()
  func signOut()
  func configure(_ user: User?)

  func changeDisplayName(to displayName: String)
  func changeProfilePicURL(to url: URL?)
  func changeProfilePicData(to data: Data)
}
