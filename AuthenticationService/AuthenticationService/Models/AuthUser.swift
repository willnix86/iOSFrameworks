//
//  User.swift
//  ENdi
//
//  Created by Will Nixon on 7/26/21.
//

import Foundation

public class AuthUser {
  var userID: String?
  var displayName: String?
  var profilePic: Data?
  var state: AuthState = .unauthenticated

  public func setUserID(id: String) {
    userID = id
  }

  public func setDisplayName(displayName: String) {
    if !displayName.isEmpty {
      self.displayName = displayName
    }
  }

  public func setProfilePic(data: Data) {
    if !data.isEmpty {
      self.profilePic = data
    }
  }

  public func downloadProfilePic(from url: URL, completion: @escaping (() -> Void)) {
    getData(from: url) { data, response, error in
      guard let downloadedData = data, error == nil else { return }
      self.setProfilePic(data: downloadedData)
      completion()
    }
  }

  public func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
    URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
  }
}
