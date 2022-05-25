//
// Copyright (C) 2017 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import UIKit
import SmartCardIO
import ACSSmartCardIO

/// The `TerminalListViewController` class shows card terminals for selection.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    12 Dec 2017
class TerminalListViewController: UITableViewController {

    @IBOutlet weak var scanButton: UIBarButtonItem!

    /// The array of card terminals
    var terminals = [CardTerminal]()

    /// The selected card terminal
    var terminal: CardTerminal?

    /// The delegate object you want to receive terminal list view controller
    /// events.
    var delegate: TerminalListViewControllerDelegate?

    /// The Bluetooth terminal manager
    var manager: BluetoothTerminalManager?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        manager!.startScan(terminalType: .acr1255uj1v2)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        return terminals.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Show the terminal name on the cell.
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell",
                                                 for: indexPath)
        cell.textLabel?.text = terminals[indexPath.row].name

        // Set the check mark if the card terminal is selected.
        if let terminal = terminal,
            terminal.name == terminals[indexPath.row].name {
            cell.accessoryType = .checkmark
        }

        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: false)

        // Return if the terminal is selected.
        var foundIndex = -1
        if let terminal = terminal,
            let index = terminals.firstIndex(where: { $0 === terminal }) {

            if (index == indexPath.row) {
                return
            }

            foundIndex = index
        }

        // Set the check mark on the terminal.
        if let newCell = tableView.cellForRow(at: indexPath) {
            if newCell.accessoryType == .none {

                newCell.accessoryType = .checkmark
                terminal = terminals[indexPath.row]
                delegate?.terminalListViewController(
                    self,
                    didSelectTerminal: terminal!)
            }
        }

        // Reset the check mark on the previous terminal.
        if (foundIndex >= 0) {

            let oldIndexPath = IndexPath(row: foundIndex, section: 0)
            if let oldCell = tableView.cellForRow(at: oldIndexPath) {
                if oldCell.accessoryType == .checkmark {
                    oldCell.accessoryType = .none
                }
            }
        }
    }
}

/// The `TerminalListViewControllerDelegate` protocol defines the methods that a
/// delegate of a `TerminalListViewController` object must adopt.
protocol TerminalListViewControllerDelegate {

    /// Invoked when the card terminal is selected.
    ///
    /// - Parameters:
    ///   - terminalListViewController: the terminal list view controller
    ///   - terminal: the selected card terminal
    func terminalListViewController(
        _ terminalListViewController: TerminalListViewController,
        didSelectTerminal terminal: CardTerminal)
}
