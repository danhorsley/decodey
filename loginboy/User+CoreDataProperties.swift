//
//  User+CoreDataProperties.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var userId: String?
    @NSManaged public var username: String?
    @NSManaged public var email: String?
    @NSManaged public var displayName: String?
    @NSManaged public var avatarUrl: String?
    @NSManaged public var bio: String?
    @NSManaged public var registrationDate: Date?
    @NSManaged public var lastLoginDate: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var isVerified: Bool
    @NSManaged public var isSubAdmin: Bool
    @NSManaged public var games: Game?
    @NSManaged public var preferences: UserPreferences?
    @NSManaged public var stats: UserStats?

}

extension User : Identifiable {

}
