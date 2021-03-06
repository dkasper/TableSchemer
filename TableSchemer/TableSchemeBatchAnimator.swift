//
//  TableSchemeBatchAnimator.swift
//  TableSchemer
//
//  Created by James Richard on 11/18/14.
//  Copyright (c) 2014 Weebly. All rights reserved.
//

import UIKit

/**
    This class is passed into the closure for performing batch animations to a TableScheme. It will record
    your changes to the TableScheme's SchemeSet and Scheme visibility, and then perform them all in one batch
    at the end of the TableScheme's batch operation method.
*/
public final class TableSchemeBatchAnimator {
    private struct Row {
        let animation: UITableViewRowAnimation
        let scheme: Scheme
    }
    
    private struct Section {
        let animation: UITableViewRowAnimation
        let schemeSet: SchemeSet
    }
    
    private var rowInsertions = [Row]()
    private var rowDeletions = [Row]()
    private var rowReloads = [Row]()
    private var sectionInsertions = [Section]()
    private var sectionDeletions = [Section]()
    private var sectionReloads = [Section]()
    
    private let tableScheme: TableScheme
    private let tableView: UITableView
    
    init(tableScheme: TableScheme, withTableView tableView: UITableView) {
        self.tableScheme = tableScheme
        self.tableView = tableView
    }
    
    /**
        Shows a Scheme within a batch update using the given animation.
        
        The passed in Scheme must belong to the TableScheme.
        
        :param:     scheme          The scheme to show.
        :param:     rowAnimation    The type of animation that should be performed.
    */
    public func showScheme(scheme: Scheme, withRowAnimation rowAnimation: UITableViewRowAnimation = .Automatic) {
        rowInsertions.append(Row(animation: rowAnimation, scheme: scheme))
    }
    
    /**
        Hides a Scheme within a batch update.
        
        The passed in Scheme must belong to the TableScheme.
        
        :param:     scheme          The scheme to hide.
        :param:     rowAnimation    The type of animation that should be performed.
    */
    public func hideScheme(scheme: Scheme, withRowAnimation rowAnimation: UITableViewRowAnimation = .Automatic) {
        rowDeletions.append(Row(animation: rowAnimation, scheme: scheme))
    }
    
    /**
        Reloads a Scheme within a batch update.
    
        The passed in Scheme must belong to the TableScheme.
        
        :param:     scheme          The scheme to reload.
        :param:     rowAnimation    The type of animation that should be performed.
    */
    public func reloadScheme(scheme: Scheme, withRowAnimation rowAnimation: UITableViewRowAnimation = .Automatic) {
        rowReloads.append(Row(animation: rowAnimation, scheme: scheme))
    }
    
    /**
        Shows a SchemeSet within a batch update using the given animation.
        
        The passed in SchemeSet must belong to the TableScheme.
        
        :param:     schemeSet       The schemeSet to hide.
        :param:     rowAnimation    The type of animation that should be performed.
    */
    public func showSchemeSet(schemeSet: SchemeSet, withRowAnimation rowAnimation: UITableViewRowAnimation = .Automatic) {
        sectionInsertions.append(Section(animation: rowAnimation, schemeSet: schemeSet))
    }
    
    /**
        Hides a SchemeSet within a batch update using the given animation.
        
        The passed in SchemeSet must belong to the TableScheme.
        
        :param:     schemeSet       The schemeSet to hide.
        :param:     rowAnimation    The type of animation that should be performed.
    */
    public func hideSchemeSet(schemeSet: SchemeSet, withRowAnimation rowAnimation: UITableViewRowAnimation = .Automatic) {
        sectionDeletions.append(Section(animation: rowAnimation, schemeSet: schemeSet))
    }
    
    /**
        Reloads a SchemeSet within a batch update.
        
        The passed in SchemeSet must belong to the TableScheme.
        
        :param:     schemeSet       The schemeSet to reload.
        :param:     rowAnimation    The type of animation that should be performed.
    */
    public func reloadSchemeSet(schemeSet: SchemeSet, withRowAnimation rowAnimation: UITableViewRowAnimation = .Automatic) {
        sectionReloads.append(Section(animation: rowAnimation, schemeSet: schemeSet))
    }
    
    // MARK: - Internal methods
    func performVisibilityChanges() {
        // Don't notify table view of changes in hidden scheme sets, or scheme sets we're already notifying about.
        let ignoredSchemeSets = tableScheme.schemeSets.filter { $0.hidden } + (sectionDeletions + sectionInsertions + sectionReloads).map { $0.schemeSet }

        // Get the index paths of the schemes we are deleting. This will give us the deletion index paths. We need to do
        // this before marking them as hidden so indexPathForScheme doesn't skip it

        let deleteRows = rowDeletions.filter {
            find(ignoredSchemeSets, self.tableScheme.schemeSetWithScheme($0.scheme)) == nil
        }.reduce([UITableViewRowAnimation: [NSIndexPath]]()) { (var memo, change) in
            if memo[change.animation] == nil {
                memo[change.animation] = [NSIndexPath]()
            }
            
            memo[change.animation]! += self.tableScheme.indexPathsForScheme(change.scheme)
            
            return memo
        }
        
        let deleteSections = sectionDeletions.reduce([UITableViewRowAnimation: NSMutableIndexSet]()) { (var memo, change) in
            if memo[change.animation] == nil {
                memo[change.animation] = NSMutableIndexSet() as NSMutableIndexSet
            }
            
            memo[change.animation]!.addIndex(self.tableScheme.sectionForSchemeSet(change.schemeSet))
            
            return memo
        }
        
        // We also need the index paths of the reloaded schemes and sections before making changes to the table.
        
        let reloadRows = rowReloads.filter {
            find(ignoredSchemeSets, self.tableScheme.schemeSetWithScheme($0.scheme)) == nil
        }.reduce([UITableViewRowAnimation: [NSIndexPath]]()) { (var memo, change) in
            if memo[change.animation] == nil {
                memo[change.animation] = [NSIndexPath]()
            }
            
            memo[change.animation]! += self.tableScheme.indexPathsForScheme(change.scheme)
            
            return memo
        }
        
        let reloadSections = sectionReloads.reduce([UITableViewRowAnimation: NSMutableIndexSet]()) { (var memo, change) in
            if memo[change.animation] == nil {
                memo[change.animation] = NSMutableIndexSet() as NSMutableIndexSet
            }
            
            memo[change.animation]!.addIndex(self.tableScheme.sectionForSchemeSet(change.schemeSet))
            
            return memo
        }
        
        // Now update the visibility of all our batches
        
        for change in rowInsertions {
            change.scheme._hidden = false
        }
        
        for change in rowDeletions {
            change.scheme._hidden = true
        }
        
        for change in sectionDeletions {
            change.schemeSet._hidden = true
        }
        
        for change in sectionInsertions {
            change.schemeSet._hidden = false
        }
        
        // Now obtain the index paths for the inserted schemes. These will have their inserted index paths, skipping ones removed,
        // and correctly finding the ones that are visible
        
        let insertRows = rowInsertions.filter {
            find(ignoredSchemeSets, self.tableScheme.schemeSetWithScheme($0.scheme)) == nil
        }.reduce([UITableViewRowAnimation: [NSIndexPath]]()) { (var memo, change) in
            if memo[change.animation] == nil {
                memo[change.animation] = [NSIndexPath]()
            }
            
            memo[change.animation]! += self.tableScheme.indexPathsForScheme(change.scheme)
            
            return memo
        }
        
        let insertSections = sectionInsertions.reduce([UITableViewRowAnimation: NSMutableIndexSet]()) { (var memo, change) in
            if memo[change.animation] == nil {
                memo[change.animation] = NSMutableIndexSet() as NSMutableIndexSet
            }
            
            memo[change.animation]!.addIndex(self.tableScheme.sectionForSchemeSet(change.schemeSet))
            
            return memo
        }
        
        // Now we have all the data we need to execute our animations. Perform them!
        
        for (animation, changes) in insertRows {
            tableView.insertRowsAtIndexPaths(changes, withRowAnimation: animation)
        }
        
        for (animation, changes) in deleteRows {
            tableView.deleteRowsAtIndexPaths(changes, withRowAnimation: animation)
        }
        
        for (animation, changes) in insertSections {
            tableView.insertSections(changes, withRowAnimation: animation)
        }
        
        for (animation, changes) in deleteSections {
            tableView.deleteSections(changes, withRowAnimation: animation)
        }
        
        for (animation, changes) in reloadRows {
            tableView.reloadRowsAtIndexPaths(changes, withRowAnimation: animation)
        }
        
        for (animation, changes) in reloadSections {
            tableView.reloadSections(changes, withRowAnimation: animation)
        }
    }
}
