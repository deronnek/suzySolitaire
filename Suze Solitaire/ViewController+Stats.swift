//
//  ViewController+Stats.swift
//  Suze Solitaire
//

import UIKit

// Stats over every finished game: streaks, money, moves and time, shown on the Stats page alongside the wins and losses.
// A game counts when it's won, or lost by dealing a new one.  Moves are card moves, including the cards Auto Moves puts
// up; deals and Undo don't count.  The clock only runs while the app is open.  They're saved with the game, so undoing
// a New Game takes its loss back out of them too.
struct GameStats: Codable, Equatable {
    // Games won and lost since stats were first kept
    var games = 0
    var streak = 0
    var bestStreak = 0
    // Cards put up and the money won or lost, per game, counting the $45 a game costs and the $250 for winning
    var cardsUp = 0
    var bestGame: Int? = nil
    var worstGame: Int? = nil
    // Moves and time, over the games they were counted for: not the one being played when stats were added
    var timedGames = 0
    var timedWins = 0
    var moves = 0
    var winMoves = 0
    var seconds: TimeInterval = 0
    var fewestWinMoves: Int? = nil
    var fastestWin: TimeInterval? = nil

    // moves and seconds are nil for a game that began before stats were kept
    mutating func record(won: Bool, cardsUp: Int, moves: Int?, seconds: TimeInterval?) {
        self.games += 1
        self.streak     = won ? self.streak + 1 : 0
        self.bestStreak = max(self.bestStreak, self.streak)
        self.cardsUp += cardsUp
        let money = GameStats.money(cardsUp: cardsUp, won: won)
        self.bestGame  = max(self.bestGame ?? money, money)
        self.worstGame = min(self.worstGame ?? money, money)
        guard let moves = moves, let seconds = seconds else {
            return
        }
        self.timedGames += 1
        self.moves      += moves
        self.seconds    += seconds
        if won {
            self.timedWins += 1
            self.winMoves  += moves
            self.fewestWinMoves = min(self.fewestWinMoves ?? moves, moves)
            self.fastestWin     = min(self.fastestWin ?? seconds, seconds)
        }
    }

    static func money(cardsUp: Int, won: Bool) -> Int {
        return 5 * cardsUp - 45 + (won ? 250 : 0)
    }
}

extension ViewController {

    // MARK: The game being played

    // Cards put up this game, leaving out the one dealt to start the upper stacks
    var cardsUpThisGame: Int {
        return max(0, self.suitStacks.reduce(0) { $0 + ($1?.cards.count ?? 0) } - 1)
    }

    // How long this game has been played with the app open
    var gameElapsed: TimeInterval {
        return self.gameSeconds + (self.gameClockStart.map { -$0.timeIntervalSinceNow } ?? 0)
    }

    func setUpGameClock() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.pauseGameClock), name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.startGameClock), name: UIScene.didActivateNotification, object: nil)
    }

    @objc func startGameClock() {
        guard self.gameClockStart == nil, !self.justWon else {
            return
        }
        self.gameClockStart = Date()
    }

    @objc func pauseGameClock() {
        self.gameSeconds    = self.gameElapsed
        self.gameClockStart = nil
    }

    // A freshly dealt game, with its moves and time counted from zero
    func startGameStats() {
        self.gameMoves      = 0
        self.gameSeconds    = 0
        self.gameClockStart = nil
        self.startGameClock()
    }

    func countMove() {
        self.gameMoves = self.gameMoves.map { $0 + 1 }
    }

    // Adds the game being played to the stats, as won or lost
    func recordGame(won: Bool) {
        self.pauseGameClock()
        self.stats.record(won: won, cardsUp: self.cardsUpThisGame, moves: self.gameMoves,
                          seconds: self.gameMoves == nil ? nil : self.gameSeconds)
    }

    // Brings back the stats in a snapshot, and with game, the moves and time of the game it was taken in
    func restoreStats(from saved: SavedGame, game: Bool) {
        self.stats = saved.stats ?? GameStats()
        if game {
            self.gameMoves      = saved.gameMoves
            self.gameSeconds    = saved.gameSeconds ?? 0
            self.gameClockStart = nil
            self.startGameClock()
        }
    }

    // MARK: Stats page

    func setUpStatsTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.showStats))
        self.chalkLine.isUserInteractionEnabled = true
        self.chalkLine.addGestureRecognizer(tap)
        self.chalkLine.accessibilityTraits = .button
        self.chalkLine.accessibilityHint   = "Shows your stats"
    }

    @objc func showStats() {
        guard self.navigationController?.topViewController === self else {
            return
        }
        let page = StatsViewController { [unowned self] in
            StatsViewController.Numbers(stats: self.stats, wins: self.wins, losses: self.losses, score: self.score)
        } reset: { [unowned self] in
            self.resetStats()
        }
        self.navigationController?.pushViewController(page, animated: true)
    }

    func resetStats() {
        // Undoing a New Game would bring the old counts back
        self.undoHistory.removeAll()
        if self.gameBeforeNewGame != nil {
            self.gameBeforeNewGame = nil
            self.canUndo = false
        }
        self.wins   = 0
        self.losses = 0
        self.stats  = GameStats()
        self.saveGame()
        self.announce("Stats reset")
    }
}

// The Stats page: results, money, moves and time, with a button to reset them
class StatsViewController: UITableViewController {

    struct Numbers {
        var stats: GameStats
        var wins: Int
        var losses: Int
        var score: Int
    }

    private struct Section {
        var title: String
        var rows: [(String, String)]
        var footer: String? = nil
    }

    private let numbers: () -> Numbers
    private let reset: () -> Void
    private var sections = [Section]()

    init(numbers: @escaping () -> Numbers, reset: @escaping () -> Void) {
        self.numbers = numbers
        self.reset   = reset
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Stats"
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.reload()
    }

    private func reload() {
        self.sections = StatsViewController.sections(for: self.numbers())
        self.tableView.reloadData()
    }

    private static let none = "—"

    private static func dollars(_ amount: Int) -> String {
        return String(format: "$%d", amount)
    }

    // 3:05, or 1:02:05 past an hour
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600, minutes = total / 60 % 60, secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }

    private static func average(_ total: Double, over count: Int, format: String = "%.0f") -> String {
        return count == 0 ? StatsViewController.none : String(format: format, total / Double(count))
    }

    private static func sections(for numbers: Numbers) -> [Section] {
        let stats = numbers.stats
        let played = numbers.wins + numbers.losses
        let none = StatsViewController.none
        return [
            Section(title: "Results", rows: [
                ("Wins", "\(numbers.wins)"),
                ("Losses", "\(numbers.losses)"),
                ("Win Rate", played == 0 ? none : String(format: "%.0f%%", 100 * Double(numbers.wins) / Double(played))),
                ("Current Streak", "\(stats.streak)"),
                ("Best Streak", "\(stats.bestStreak)"),
            ]),
            Section(title: "Money", rows: [
                ("Total", dollars(numbers.score)),
                ("Best Game", stats.bestGame.map(dollars) ?? none),
                ("Worst Game", stats.worstGame.map(dollars) ?? none),
                ("Cards Up per Game", average(Double(stats.cardsUp), over: stats.games, format: "%.1f")),
            ]),
            Section(title: "Moves", rows: [
                ("Average per Game", average(Double(stats.moves), over: stats.timedGames)),
                ("Average per Win", average(Double(stats.winMoves), over: stats.timedWins)),
                ("Fewest in a Win", stats.fewestWinMoves.map { "\($0)" } ?? none),
            ]),
            Section(title: "Time", rows: [
                ("Average per Game", stats.timedGames == 0 ? none : duration(stats.seconds / Double(stats.timedGames))),
                ("Fastest Win", stats.fastestWin.map(duration) ?? none),
            ], footer: "Wins and losses go back to your first game. Everything else counts games finished since Stats was added. Time only counts while the app is open."),
        ]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section < self.sections.count ? self.sections[section].rows.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section < self.sections.count ? self.sections[section].title : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section < self.sections.count ? self.sections[section].footer : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if indexPath.section < self.sections.count {
            let (title, value) = self.sections[indexPath.section].rows[indexPath.row]
            var content = UIListContentConfiguration.valueCell()
            content.text          = title
            content.secondaryText = value
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            cell.accessibilityTraits = .staticText
        }
        else {
            var content = UIListContentConfiguration.cell()
            content.text = "Reset Stats…"
            content.textProperties.color     = .systemRed
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            cell.accessibilityTraits = .button
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == self.sections.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let alert = UIAlertController(title: "Reset Stats?",
                                      message: "Your wins, losses and other stats will go back to zero. Your money and the current game won't change.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.reset()
            self?.reload()
        })
        self.present(alert, animated: true)
    }
}
