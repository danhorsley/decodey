//
//  UserPreferences+CoreDataProperties.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//
//

import Foundation
import CoreData


extension UserPreferences {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPreferences> {
        return NSFetchRequest<UserPreferences>(entityName: "UserPreferences")
    }

    @NSManaged public var darkMode: Bool
    @NSManaged public var showTextHelpers: NSObject?
    @NSManaged public var accessibilityTextSize: Bool
    @NSManaged public var gameDifficulty: String?
    @NSManaged public var soundEnabled: Bool
    @NSManaged public var soundVolume: Float
    @NSManaged public var useBiometricAuth: Bool
    @NSManaged public var notificationsEnabled: Bool
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var user: User?

}

extension UserPreferences : Identifiable {

}
