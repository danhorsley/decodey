//
//  Quote+CoreDataProperties.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//
//

import Foundation
import CoreData


extension Quote {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Quote> {
        return NSFetchRequest<Quote>(entityName: "Quote")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var author: String?
    @NSManaged public var attribution: String?
    @NSManaged public var difficulty: Double
    @NSManaged public var isDaily: Bool
    @NSManaged public var dailyDate: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var timesUsed: Int32
    @NSManaged public var uniqueLetters: Int16
    @NSManaged public var serverId: Int32
    @NSManaged public var games: Game?

}

extension Quote : Identifiable {

}
