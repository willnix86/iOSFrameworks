//
//  AuthError.swift
//  ENdi
//
//  Created by Will Nixon on 7/26/21.
//

import Foundation

public enum AuthError: String, Swift.Error {
  case emailInUse = "The email address you provided is already in use"
  case invalidEmail = "Invalid email address"
  case invalidPassword = "Incorrect password"
  case tooManyRequests = "Too many failed sign in requests. Please try again in 15 minutes"
  case userNotFound = "User not found"
  case connectivity = "Network connection error"
  case weakPassword = "Password doesn't match current policy. Please try a stronger password"
  case emailRequired = "An email address is required"
  case authError = "Error signing in"
  case missingDetails = "Please input your email address and password"
  case passwordRequired = "A password is required"
  case signOutError = "Error signing out"
}
