//
// Copyright (C) 2017 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import Foundation
import UIKit
import SmartCardIO
import ACSSmartCardIO

/// The `MainViewController` class is the main screen that demonstrates the
/// functionality of Bluetooth card terminal.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    9 Dec 2017
class MainViewController: UITableViewController {

    @IBOutlet weak var terminalLabel: UILabel!
    @IBOutlet weak var terminalTimeoutsLabel: UILabel!
    @IBOutlet weak var protocolLabel: UILabel!
    @IBOutlet weak var controlCodeTextField: UITextField!
    @IBOutlet weak var showCardStateLabel: UILabel!
    @IBOutlet weak var logTextView: UITextView!

    static let keyPrefT0GetResponse = "pref_t0_get_response"
    static let keyPrefT1GetResponse = "pref_t1_get_response"
    static let keyPrefT1StripLe = "pref_t1_strip_le"

    static let keyPrefUseDefaultKey = "pref_use_default_key"
    static let keyPrefNewKey = "pref_new_key"
    static let keyPrefConnectionTimeout = "pref_connection_timeout"
    static let keyPrefPowerTimeout = "pref_power_timeout"
    static let keyPrefProtocolTimeout = "pref_protocol_timeout"
    static let keyPrefApduTimeout = "pref_apdu_timeout"
    static let keyPrefControlTimeout = "pref_control_timeout"

    let manager = BluetoothSmartCard.shared.manager
    let factory = BluetoothSmartCard.shared.factory
    weak var terminalListViewController: TerminalListViewController?
    var terminal: CardTerminal?
    var protocols = [ true, true ]
    var filename: String?
    var logger: Logger!
    let cardStateMonitor = CardStateMonitor.shared
    var firstRun = true

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // Set the delegate.
        manager.delegate = self
        cardStateMonitor.delegate = self

        // Initialize the text.
        terminalLabel.text = ""
        terminalTimeoutsLabel.text = ""
        controlCodeTextField.text = String(BluetoothTerminalManager.ioctlEscape)

        // Initialize the logger.
        logger = Logger(textView: logTextView)

        // Set default values.
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            MainViewController.keyPrefT0GetResponse: true,
            MainViewController.keyPrefT1GetResponse: true,
            MainViewController.keyPrefT1StripLe: false])

        // Register for defaults changed.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil)

        // Load the settings.
        loadSettings()
    }

    @objc func defaultsChanged(notification: NSNotification) {
        loadSettings()
    }

    /// Loads the settings.
    func loadSettings() {

        logger.logMsg("Loading the settings...")

        let defaults = UserDefaults.standard
        TransmitOptions.t0GetResponse = defaults.bool(
            forKey: MainViewController.keyPrefT0GetResponse)
        TransmitOptions.t1GetResponse = defaults.bool(
            forKey: MainViewController.keyPrefT1GetResponse)
        TransmitOptions.t1StripLe = defaults.bool(
            forKey: MainViewController.keyPrefT1StripLe)

        logger.logMsg("Transmit Options")
        logger.logMsg("- t0GetResponse: \(TransmitOptions.t0GetResponse)")
        logger.logMsg("- t1GetResponse: \(TransmitOptions.t1GetResponse)")
        logger.logMsg("- t1StripLe: \(TransmitOptions.t1StripLe)")
    }

    deinit {

        // Unregister the observer on iOS < 9.0 and macOS < 10.11.
        if #available(iOS 9.0, macOS 10.11, *) {
        } else {
            NotificationCenter.default.removeObserver(self)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func shouldPerformSegue(withIdentifier identifier: String,
                                     sender: Any?) -> Bool {

        if identifier == "SetMasterKey"
            || identifier == "SetTerminalTimeouts" {

            // Check the selected card terminal.
            if terminal == nil {

                logger.logMsg("Error: Card terminal not selected")
                return false
            }
        }

        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if let identifier = segue.identifier {
            switch identifier {

            case "ScanTerminals":
                if let navigationViewController = segue.destination
                    as? UINavigationController,

                    let topViewController = navigationViewController
                        .topViewController,

                    let terminalListViewController = topViewController
                        as? TerminalListViewController {

                    // Show the selected card terminal.
                    terminalListViewController.terminal = terminal

                    // Set the manager for scan.
                    terminalListViewController.manager = manager

                    // Store the terminal list view controller.
                    self.terminalListViewController = terminalListViewController
                }

            case "ListTerminals":
                if let terminalListViewController = segue.destination
                    as? TerminalListViewController {

                    // List terminals from factory.
                    do {
                        terminalListViewController.terminals = try factory
                            .terminals().list()
                    } catch {
                        logger.logMsg("ListTerminals: "
                            + error.localizedDescription)
                    }

                    // Show the selected card terminal.
                    terminalListViewController.terminal = terminal
                    // Set the manager for scan.
                    terminalListViewController.manager = manager
                    terminalListViewController.delegate = self
                }


            case "SetTerminalTimeouts":
                if let terminalTimeoutsViewController = segue.destination
                    as? TerminalTimeoutsViewController,
                    let terminal = terminal,
                    let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                        + terminal.name) {

                    // Load the settings.
                    let connectionTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefConnectionTimeout)
                    let powerTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefPowerTimeout)
                    let protocolTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefProtocolTimeout)
                    let apduTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefApduTimeout)
                    let controlTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefControlTimeout)

                    terminalTimeoutsViewController.connectionTimeout = connectionTimeout
                    terminalTimeoutsViewController.powerTimeout = powerTimeout
                    terminalTimeoutsViewController.protocolTimeout = protocolTimeout
                    terminalTimeoutsViewController.apduTimeout = apduTimeout
                    terminalTimeoutsViewController.controlTimeout = controlTimeout
                    terminalTimeoutsViewController.delegate = self
                }

            default:
                break
            }
        }
    }

    @IBAction func unwindToMain(segue: UIStoryboardSegue) {

        if let identifier = segue.identifier {
            switch identifier {

            case "ReturnTerminal":
                // Stop the scan.
                manager.stopScan()

                if let terminalListViewController = segue.source
                    as? TerminalListViewController,
                    let terminal = terminalListViewController.terminal,
                    let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                        + terminal.name) {

                    // Store the selected card terminal.
                    self.terminal = terminal

                    // Show the name.
                    terminalLabel.text = terminal.name

                    // Load the settings.
                    let isDefaultKeyUsed = defaults.bool(
                        forKey: MainViewController.keyPrefUseDefaultKey)
                    let connectionTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefConnectionTimeout)
                    let powerTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefPowerTimeout)
                    let protocolTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefProtocolTimeout)
                    let apduTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefApduTimeout)
                    let controlTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefControlTimeout)

                    // Show the settings.
                    terminalTimeoutsLabel.text =
                        connectionTimeout == TerminalTimeouts.defaultTimeout
                        && powerTimeout == TerminalTimeouts.defaultTimeout
                        && protocolTimeout == TerminalTimeouts.defaultTimeout
                        && apduTimeout == TerminalTimeouts.defaultTimeout
                        && controlTimeout == TerminalTimeouts.defaultTimeout ?
                            "Default Timeout" : "Custom Timeout"
                    showCardStateLabel.text =
                        cardStateMonitor.isTerminalEnabled(terminal) ?
                            "Hide Card State" : "Show Card State"

                    // Update the table view.
                    tableView.reloadData()
                }

            case "CancelTerminal":
                // Stop the scan.
                manager.stopScan()

            default:
                break
            }
        }
    }

    /// Runs the script.
    ///
    /// - Parameters:
    ///   - card: the card
    ///   - command: 16進数コマンド
    ///   - send: the closure for sending command and receiving response
    func runScript(card: Card,
                   hexCommand: String,
                   send: (Card, [UInt8]) throws -> [UInt8]) {

        // Open the log file.
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let logFilename = "Log-" + dateFormatter.string(from: currentDate)
            + ".txt"
        logger.openLogFile(name: logFilename)

        do {

            var numCommands = 0
            while true {

                var commandLoaded = false
                var responseLoaded = false
                var command = [UInt8]()

                // Read the first line.
                while hexCommand.count > 0 {

                    // Skip the comment line.
                    if !hexCommand.contains(";") {

                        if !commandLoaded {

                            command = Hex.toByteArray(hexString: hexCommand)
                            if command.count > 0 {
                                commandLoaded = true
                            }

                        } else {

                            if checkLine(hexCommand) > 0 {
                                responseLoaded = true
                            }
                        }
                    }

                    if commandLoaded && responseLoaded {
                        break
                    }
                }

                if !commandLoaded || !responseLoaded {
                    break
                }

                // Increment the number of loaded commands.
                numCommands += 1

                logger.logMsg("Command:")
                logger.logBuffer(command)

                // Send the command.
                let startTime = Date()
                let response = try send(card, command)
                let endTime = Date()
                let time = endTime.timeIntervalSince(startTime)

                logger.logMsg("Response:")
                logger.logBuffer(response)

                logger.logMsg("Bytes Sent    : %d", command.count)
                logger.logMsg("Bytes Received: %d", response.count)
                logger.logMsg("Transfer Time : %.2f ms", time * 1000.0)
                logger.logMsg("Transfer Rate : %.2f bytes/second",
                              Double(command.count + response.count) / time)

                logger.logMsg("Expected:")
                logger.logHexString(hexCommand)

                // Compare the response.
                if compareResponse(line: hexCommand, response: response) {

                    logger.logMsg("Compare OK")

                } else {

                    logger.logMsg("Error: Unexpected response")
                    break
                }
            }

            if numCommands == 0 {
                logger.logMsg("Error: Cannot load the command")
            }

        } catch {

            logger.logMsg("Error: " + error.localizedDescription)
        }

        // Close the log file.
        logger.closeLogFile()
    }

    /// Opens the file.
    ///
    /// - Parameter name: the filename
    /// - Returns: the file handle
    func openFile(name: String) -> FileHandle? {

        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                        .userDomainMask,
                                                        true)
        let documentsDirectory = paths[0]
        let filePath = NSString(string: documentsDirectory)
            .appendingPathComponent(name)

        return FileHandle(forReadingAtPath: filePath)
    }


    /// Checks the line.
    ///
    /// - Parameter line: the line
    /// - Returns: the number of characters
    func checkLine(_ line: String) -> Int {

        var count = 0

        for c in line {
            if c >= Character("0") && c <= Character("9")
                || c >= Character("A") && c <= Character("F")
                || c >= Character("a") && c <= Character("f")
                || c == Character("X")
                || c == Character("x") {
                count += 1
            }
        }

        return count
    }

    /// Compares the response with line.
    ///
    /// - Parameters:
    ///   - line: the line
    ///   - response: the response
    func compareResponse(line: String, response: [UInt8]) -> Bool {

        var ret = true
        var length = 0
        var first = true
        var num = 0
        var num2 = 0
        var i = 0

        let digit0: Unicode.Scalar = "0"
        let digit9: Unicode.Scalar = "9"
        let letterA: Unicode.Scalar = "A"
        let letterF: Unicode.Scalar = "F"
        let letterX: Unicode.Scalar = "X"
        let lettera: Unicode.Scalar = "a"
        let letterf: Unicode.Scalar = "f"
        let letterx: Unicode.Scalar = "x"

        for c in line.unicodeScalars {

            if c >= digit0 && c <= digit9 {
                num = Int(c.value - digit0.value)
            } else if c >= letterA && c <= letterF {
                num = Int(c.value - letterA.value + 10)
            } else if c >= lettera && c <= letterf {
                num = Int(c.value - lettera.value + 10)
            } else {
                num = -1
            }

            if num >= 0 || c == letterX || c == letterx {

                // Increment the string length.
                length += 1

                if i >= response.count {

                    ret = false
                    break
                }

                if first {

                    num2 = Int(response[i]) >> 4 & 0x0F

                } else {

                    num2 = Int(response[i]) & 0x0F
                    i += 1
                }

                first = !first

                if c == letterX || c == letterx {
                    num = num2
                }

                // Compare two numbers.
                if num2 != num {

                    ret = false
                    break
                }
            }
        }

        // Return false if the length is not matched.
        if length != 2 * response.count {
            ret = false
        }

        return ret
    }

    // MARK: - Table View

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: false)

        if let cell = tableView.cellForRow(at: indexPath),
            let reuseIdentifier = cell.reuseIdentifier {
            switch reuseIdentifier {

            case "ShowCardState":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Show or hide the card state.
                if cardStateMonitor.isTerminalEnabled(terminal) {

                    cardStateMonitor.removeTerminal(terminal)
                    showCardStateLabel.text = "Show Card State"

                } else {

                    cardStateMonitor.addTerminal(terminal)
                    showCardStateLabel.text = "Hide Card State"
                }

                // Update the table view.
                tableView.reloadData()
                break;

            case "Transmit":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Check the selected protocol.
                var protocolString = ""
                if protocols[0] {
                    if protocols[1] {
                        protocolString = "*"
                    } else {
                        protocolString = "T=0"
                    }
                } else {
                    if protocols[1] {
                        protocolString = "T=1"
                    } else {
                        logger.logMsg("Error: Protocol not selected")
                        break
                    }
                }

                // Clear the log.
                logger.clear()

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        // Connect to the card.
                        self.logger.logMsg("Connecting to the card ("
                            + terminal.name + ", " + protocolString + ")...")
                        let card = try terminal.connect(
                            protocolString: protocolString)

                        // Get the ATR string.
                        self.logger.logMsg("ATR:")
                        self.logger.logBuffer(card.atr.bytes)

                        // Get the active protocol.
                        self.logger.logMsg("Active Protocol: "
                            + card.activeProtocol)

                        // Run the script.
                        self.runScript(card: card,hexCommand: getIdmCommand) {
                            let channel = try $0.basicChannel()
                            let commandAPDU = try CommandAPDU(apdu: $1)
                            let responseAPDU = try channel.transmit(
                                apdu: commandAPDU)

                            return responseAPDU.bytes
                        }

                        // Disconnect from the card.
                        self.logger.logMsg("Disconnecting the card ("
                            + terminal.name + ")...")
                        try card.disconnect(reset: false)

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            case "Control":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Check the control code.
                var controlCode = 0
                if let numberString = controlCodeTextField.text,
                    let number = Int(numberString) {

                    controlCode = number

                } else {

                    logger.logMsg("Error: Invalid control code")
                    break
                }

                // Clear the log.
                logger.clear()

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        // Connect to the card.
                        self.logger.logMsg("Connecting to the card ("
                            + terminal.name + ", direct)...")
                        let card = try terminal.connect(
                            protocolString: "direct")

                        // Run the script.
                        self.runScript(card: card,hexCommand: getIdmCommand) {
                            return try $0.transmitControlCommand(
                                controlCode: controlCode,
                                command: $1)
                        }

                        // Disconnect from the card.
                        self.logger.logMsg("Disconnecting the card ("
                            + terminal.name + ")...")
                        try card.disconnect(reset: false)

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            case "Disconnect":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Remove the terminal from card state monitor.
                cardStateMonitor.removeTerminal(terminal)
                showCardStateLabel.text = "Show Card State"
                tableView.reloadData()

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        // Disconnect from the terminal.
                        self.logger.logMsg("Disconnecting " + terminal.name
                            + "...")
                        try self.manager.disconnect(terminal: terminal)

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            default:
                break
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension MainViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        if textField == controlCodeTextField {
            textField.resignFirstResponder()
        }

        return true
    }
}

// MARK: - BluetoothTerminalManagerDelegate
extension MainViewController: BluetoothTerminalManagerDelegate {

    func bluetoothTerminalManagerDidUpdateState(
        _ manager: BluetoothTerminalManager) {

        var message = ""

        switch manager.centralManager.state {

        case .unknown, .resetting:
            message = "The update is being started. Please wait until Bluetooth is ready."

        case .unsupported:
            message = "This device does not support Bluetooth low energy."

        case .unauthorized:
            message = "This app is not authorized to use Bluetooth low energy."

        case .poweredOff:
            if !firstRun {
                message = "You must turn on Bluetooth in Settings in order to use the reader."
            }

        default:
            break
        }

        if !message.isEmpty {

            // Show the alert.
            let alert = UIAlertController(title: "Bluetooth",
                                          message: message,
                                          preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "OK", style: .default)
            alert.addAction(defaultAction)
            DispatchQueue.main.async {
                self.present(alert, animated: true)
            }
        }

        firstRun = false
    }

    func bluetoothTerminalManager(_ manager: BluetoothTerminalManager,
                                  didDiscover terminal: CardTerminal) {

        // Show the terminal.
        if let terminalListViewController = terminalListViewController {
            if !terminalListViewController.terminals.contains(
                where: { $0 === terminal }) {

                terminalListViewController.terminals.append(terminal)
                DispatchQueue.main.async {
                    terminalListViewController.tableView.reloadData()
                }

                if let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                    + terminal.name) {

                    // Set default values.
                    defaults.register(defaults: [
                        MainViewController.keyPrefUseDefaultKey: true,
                        MainViewController.keyPrefNewKey: "",
                        MainViewController.keyPrefConnectionTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefPowerTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefProtocolTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefApduTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefControlTimeout:
                            TerminalTimeouts.defaultTimeout])

                    // Load the settings.
                    let isDefaultKeyUsed = defaults.bool(
                        forKey: MainViewController.keyPrefUseDefaultKey)
                    let newKey = defaults.string(
                        forKey: MainViewController.keyPrefNewKey) ?? ""
                    let connectionTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefConnectionTimeout)
                    let powerTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefPowerTimeout)
                    let protocolTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefProtocolTimeout)
                    let apduTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefApduTimeout)
                    let controlTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefControlTimeout)

                    // Set the master key.
                    if !isDefaultKeyUsed {

                        logger.logMsg("Setting the master key (" + terminal.name
                            + ")...")
                        do {
                            try manager.setMasterKey(
                                terminal: terminal,
                                masterKey: Hex.toByteArray(hexString: newKey))
                        } catch {
                            logger.logMsg("Error: "
                                + error.localizedDescription)
                        }
                    }

                    // Set the terminal timeouts.
                    logger.logMsg("Setting the terminal timeouts ("
                        + terminal.name + ")...")
                    do {

                        let timeouts = try manager.timeouts(terminal: terminal)
                        timeouts.connectionTimeout = connectionTimeout
                        timeouts.powerTimeout = powerTimeout
                        timeouts.protocolTimeout = protocolTimeout
                        timeouts.apduTimeout = apduTimeout
                        timeouts.controlTimeout = controlTimeout

                    } catch {

                        logger.logMsg("Error: " + error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - TerminalListViewControllerDelegate
extension MainViewController: TerminalListViewControllerDelegate {

    func terminalListViewController(
        _ terminalListViewController: TerminalListViewController,
        didSelectTerminal terminal: CardTerminal) {

        // Store the selected card terminal.
        self.terminal = terminal

        // Show the name.
        terminalLabel.text = terminal.name

        if let defaults = UserDefaults(suiteName: "com.acs.BLETest."
            + terminal.name) {

            // Load the settings.
            let isDefaultKeyUsed = defaults.bool(
                forKey: MainViewController.keyPrefUseDefaultKey)
            let connectionTimeout = defaults.integer(
                forKey: MainViewController.keyPrefConnectionTimeout)
            let powerTimeout = defaults.integer(
                forKey: MainViewController.keyPrefPowerTimeout)
            let protocolTimeout = defaults.integer(
                forKey: MainViewController.keyPrefProtocolTimeout)
            let apduTimeout = defaults.integer(
                forKey: MainViewController.keyPrefApduTimeout)
            let controlTimeout = defaults.integer(
                forKey: MainViewController.keyPrefControlTimeout)

            // Show the settings.
            terminalTimeoutsLabel.text =
                connectionTimeout == TerminalTimeouts.defaultTimeout
                && powerTimeout == TerminalTimeouts.defaultTimeout
                && protocolTimeout == TerminalTimeouts.defaultTimeout
                && apduTimeout == TerminalTimeouts.defaultTimeout
                && controlTimeout == TerminalTimeouts.defaultTimeout ?
                    "Default Timeout" : "Custom Timeout"
            showCardStateLabel.text =
                cardStateMonitor.isTerminalEnabled(terminal) ?
                    "Hide Card State" : "Show Card State"
        }

        // Update the table view.
        tableView.reloadData()
    }
}

// MARK: - TerminalTimeoutsViewControllerDelegate
extension MainViewController: TerminalTimeoutsViewControllerDelegate {

    func terminalTimeoutsViewController(
        _ terminalTimeoutsViewController: TerminalTimeoutsViewController,
        didUpdateSettings connectionTimeout: Int,
        powerTimeout: Int,
        protocolTimeout: Int,
        apduTimeout: Int,
        controlTimeout: Int) {

        // Show the settings.
        terminalTimeoutsLabel.text =
            connectionTimeout == TerminalTimeouts.defaultTimeout
            && powerTimeout == TerminalTimeouts.defaultTimeout
            && protocolTimeout == TerminalTimeouts.defaultTimeout
            && apduTimeout == TerminalTimeouts.defaultTimeout
            && controlTimeout == TerminalTimeouts.defaultTimeout ?
                "Default Timeout" : "Custom Timeout"

        if let terminal = terminal,
            let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                + terminal.name) {

            // Save the settings.
            defaults.set(connectionTimeout,
                         forKey: MainViewController.keyPrefConnectionTimeout)
            defaults.set(powerTimeout,
                         forKey: MainViewController.keyPrefPowerTimeout)
            defaults.set(protocolTimeout,
                         forKey: MainViewController.keyPrefProtocolTimeout)
            defaults.set(apduTimeout,
                         forKey: MainViewController.keyPrefApduTimeout)
            defaults.set(controlTimeout,
                         forKey: MainViewController.keyPrefControlTimeout)

            // Set the terminal timeouts.
            logger.logMsg("Setting the terminal timeouts ("
                + terminal.name + ")...")
            do {

                let timeouts = try manager.timeouts(terminal: terminal)
                timeouts.connectionTimeout = connectionTimeout
                timeouts.powerTimeout = powerTimeout
                timeouts.protocolTimeout = protocolTimeout
                timeouts.apduTimeout = apduTimeout
                timeouts.controlTimeout = controlTimeout

            } catch {

                logger.logMsg("Error: " + error.localizedDescription)
            }
        }
    }
}

// MARK: - CardStateMonitorDelegate
extension MainViewController: CardStateMonitorDelegate {

    func cardStateMonitor(_ monitor: CardStateMonitor,
                          didChangeState terminal: CardTerminal,
                          prevState: CardStateMonitor.CardState,
                          currState: CardStateMonitor.CardState) {
        if prevState.rawValue > CardStateMonitor.CardState.absent.rawValue
            && currState.rawValue <= CardStateMonitor.CardState.absent.rawValue {
            logger.logMsg(terminal.name + ": removed")
        } else if prevState.rawValue <= CardStateMonitor.CardState.absent.rawValue
            && currState.rawValue > CardStateMonitor.CardState.absent.rawValue {
            logger.logMsg(terminal.name + ": inserted")
        }
    }
}
