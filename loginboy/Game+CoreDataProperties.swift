//
//  Game+CoreDataProperties.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//
//

import Foundation
import CoreData


extension Game {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Game> {
        return NSFetchRequest<Game>(entityName: "Game")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var encrypted: String?
    @NSManaged public var solution: String?
    @NSManaged public var currentDisplay: String?
    @NSManaged public var mistakes: Int16
    @NSManaged public var maxMistakes: Int16
    @NSManaged public var hasWon: Bool
    @NSManaged public var hasLost: Bool
    @NSManaged public var difficulty: String?
    @NSManaged public var startTime: Date?
    @NSManaged public var lastUpdateTime: Date?
    @NSManaged public var isDaily: Bool
    @NSManaged public var score: Int32
    @NSManaged public var timeTaken: Int32
    @NSManaged public var mapping: Data?
    @NSManaged public var correctMappings: Data?
    @NSManaged public var guessedMappings: Data?
    @NSManaged public var attribute: NSObject?
    @NSManaged public var attribute1: NSObject?
    @NSManaged public var attribute2: NSObject?
    @NSManaged public var attribute3: NSObject?
    @NSManaged public var quote: Quote?
    @NSManaged public var user: User?

}

extension Game : Identifiable {

}
