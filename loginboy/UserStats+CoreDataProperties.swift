//
//  UserStats+CoreDataProperties.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//
//

import Foundation
import CoreData


extension UserStats {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserStats> {
        return NSFetchRequest<UserStats>(entityName: "UserStats")
    }

    @NSManaged public var gamesPlayed: Int32
    @NSManaged public var gamesWon: Int32
    @NSManaged public var currentStreak: Int32
    @NSManaged public var bestStreak: Int32
    @NSManaged public var totalScore: Int32
    @NSManaged public var averageMistakes: Double
    @NSManaged public var averageTime: Double
    @NSManaged public var lastPlayedDate: Date?
    @NSManaged public var user: User?

}

extension UserStats : Identifiable {

}
