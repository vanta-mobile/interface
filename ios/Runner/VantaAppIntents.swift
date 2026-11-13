import AppIntents
import UIKit

// Siri, Shortcuts and Spotlight entry points (App Intents). Every intent only
// opens a `vantaapp://` link that the app validates like any other deep link;
// nothing here reads account data, places or cancels orders, moves funds or
// signs. Mirrors the Android AppFunctions in BaseVantaAppFunctionService.kt.

/// Builds `vantaapp://` links. Same rules and output as Android's VantaLinks:
/// RFC 3986 percent-encoding of UTF-8 so `&`, `=` and `+` never alter the query.
enum VantaLinks {
  static let promptMaxLength = 2000
  private static let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

  static func link(_ host: String, _ query: [(String, String?)] = []) -> URL {
    let parameters = query.compactMap { key, value -> String? in
      guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
        let encoded = text.addingPercentEncoding(withAllowedCharacters: unreserved)
      else { return nil }
      return "\(key)=\(encoded)"
    }
    let query = parameters.isEmpty ? "" : "?" + parameters.joined(separator: "&")
    // Hosts and keys are fixed ASCII and values are fully encoded, so this cannot fail.
    return URL(string: "vantaapp://\(host)\(query)")!
  }

  /// Plain positive decimal such as 3200.5: no sign, exponent or grouping.
  static func isAmount(_ text: String?) -> Bool {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
      return true
    }
    return text.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil
  }

  /// Hands the link to the app's own URL handling (app_links queues it until
  /// Flutter listens), so a cold start from Siri still reaches its page.
  @MainActor
  static func open(_ url: URL) async {
    _ = await UIApplication.shared.open(url)
  }
}

enum VantaIntentError: Error, CustomLocalizedStringResourceConvertible {
  case missingMarket
  case invalidAmount
  case questionTooLong

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .missingMarket: "Say which market, for example BTC or ETHUSDT."
    case .invalidAmount: "Prices and quantities must be plain numbers such as 3200.5."
    case .questionTooLong: "The question must be at most 2000 characters."
    }
  }
}

/// Feature IDs match `vantaapp://open?feature=` and Android's shortcuts.xml.
enum VantaPage: String, AppEnum {
  case futures, chart, orders, positions, portfolio, points, assistant, notifications

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Vanta Page"
  static let caseDisplayRepresentations: [VantaPage: DisplayRepresentation] = [
    .futures: DisplayRepresentation(title: "Futures", synonyms: ["Trade", "Trading", "Perpetuals"]),
    .chart: DisplayRepresentation(title: "Chart", synonyms: ["Price Chart", "Candlestick Chart"]),
    .orders: DisplayRepresentation(title: "Open Orders", synonyms: ["Orders", "My Orders"]),
    .positions: DisplayRepresentation(title: "Positions", synonyms: ["My Positions", "Open Positions"]),
    .portfolio: DisplayRepresentation(title: "Portfolio", synonyms: ["Assets", "Balance", "My Assets"]),
    .points: DisplayRepresentation(title: "Points", synonyms: ["Rewards", "My Points"]),
    .assistant: DisplayRepresentation(title: "Vanta AI", synonyms: ["AI Assistant", "Ask AI"]),
    .notifications: DisplayRepresentation(title: "Notifications", synonyms: ["Inbox", "Messages", "Alerts"]),
  ]
}

enum VantaMarketView: String, AppEnum {
  case trade, chart

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Market View"
  static let caseDisplayRepresentations: [VantaMarketView: DisplayRepresentation] = [
    .trade: "Order Form",
    .chart: "Chart",
  ]
}

/// Values match the `panel` link parameter.
enum VantaSection: String, AppEnum {
  case orders, positions, assets

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Account Section"
  static let caseDisplayRepresentations: [VantaSection: DisplayRepresentation] = [
    .orders: "Open Orders",
    .positions: "Positions",
    .assets: "Futures Assets",
  ]
}

enum VantaOrderType: String, AppEnum {
  case limit, market

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Order Type"
  static let caseDisplayRepresentations: [VantaOrderType: DisplayRepresentation] = [
    .limit: "Limit",
    .market: "Market",
  ]
}

enum VantaSizeUnit: String, AppEnum {
  case quote, base

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Quantity Unit"
  static let caseDisplayRepresentations: [VantaSizeUnit: DisplayRepresentation] = [
    .quote: "USDT",
    .base: "Coin",
  ]
}

struct OpenVantaPageIntent: AppIntent {
  static let title: LocalizedStringResource = "Open in Vanta"
  static let description = IntentDescription(
    "Opens a Vanta screen: futures, chart, open orders, positions, portfolio, points, Vanta AI or notifications.")
  static let openAppWhenRun = true

  @Parameter(title: "Page")
  var page: VantaPage

  @MainActor
  func perform() async throws -> some IntentResult {
    await VantaLinks.open(VantaLinks.link("open", [("feature", page.rawValue)]))
    return .result()
  }
}

struct OpenVantaMarketIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Vanta Market"
  static let description = IntentDescription(
    "Opens a perpetual futures market such as BTC or ETHUSDT, optionally on its chart or an account section. Unknown markets keep the current one.")
  static let openAppWhenRun = true

  @Parameter(title: "Market", requestValueDialog: "Which market?")
  var symbol: String

  @Parameter(title: "View")
  var view: VantaMarketView?

  @Parameter(title: "Section")
  var section: VantaSection?

  @MainActor
  func perform() async throws -> some IntentResult {
    guard !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw VantaIntentError.missingMarket
    }
    await VantaLinks.open(
      VantaLinks.link(
        "futures",
        [("symbol", symbol), ("tab", view?.rawValue), ("panel", section?.rawValue)]))
    return .result()
  }
}

/// Fills the order form only. The user still picks Long or Short, reviews the
/// confirmation (always shown for prefilled orders) and signs in Vanta.
struct PrepareVantaOrderIntent: AppIntent {
  static let title: LocalizedStringResource = "Prepare Vanta Order"
  static let description = IntentDescription(
    "Opens the Vanta order form with a market, order type, price and quantity filled in. It never places an order: you choose Long or Short, review and sign in Vanta.")
  static let openAppWhenRun = true

  @Parameter(title: "Market", requestValueDialog: "Which market?")
  var symbol: String

  @Parameter(title: "Order Type", default: .limit)
  var orderType: VantaOrderType

  @Parameter(title: "Price")
  var price: String?

  @Parameter(title: "Quantity")
  var quantity: String?

  @Parameter(title: "Quantity Unit", default: .quote)
  var unit: VantaSizeUnit

  @MainActor
  func perform() async throws -> some IntentResult {
    guard !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw VantaIntentError.missingMarket
    }
    guard VantaLinks.isAmount(price), VantaLinks.isAmount(quantity) else {
      throw VantaIntentError.invalidAmount
    }
    let hasQuantity = !(quantity ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    await VantaLinks.open(
      VantaLinks.link(
        "futures",
        [
          ("symbol", symbol),
          ("type", orderType.rawValue),
          // A market order has no limit price.
          ("price", orderType == .market ? nil : price),
          ("qty", quantity),
          ("unit", hasQuantity ? unit.rawValue : nil),
        ]))
    return .result()
  }
}

struct AskVantaAIIntent: AppIntent {
  static let title: LocalizedStringResource = "Ask Vanta AI"
  static let description = IntentDescription(
    "Opens Vanta AI with your question typed in. It is not sent until you send it.")
  static let openAppWhenRun = true

  @Parameter(title: "Question")
  var question: String?

  @MainActor
  func perform() async throws -> some IntentResult {
    let text = question?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (text?.count ?? 0) <= VantaLinks.promptMaxLength else {
      throw VantaIntentError.questionTooLong
    }
    await VantaLinks.open(VantaLinks.link("assistant", [("prompt", text)]))
    return .result()
  }
}

/// Siri phrases. Chinese phrases live in zh-Hans.lproj/AppShortcuts.strings.
struct VantaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenVantaPageIntent(),
      phrases: [
        "Open \(\.$page) in \(.applicationName)",
        "Show \(\.$page) in \(.applicationName)",
        "Show my \(\.$page) in \(.applicationName)",
      ],
      shortTitle: "Open in Vanta",
      systemImageName: "arrow.up.forward.app"
    )
    AppShortcut(
      intent: OpenVantaMarketIntent(),
      phrases: [
        "Open a market in \(.applicationName)",
        "Check a market in \(.applicationName)",
      ],
      shortTitle: "Open Market",
      systemImageName: "chart.line.uptrend.xyaxis"
    )
    AppShortcut(
      intent: PrepareVantaOrderIntent(),
      phrases: [
        "Prepare an order in \(.applicationName)",
        "Set up an order in \(.applicationName)",
      ],
      shortTitle: "Prepare Order",
      systemImageName: "square.and.pencil"
    )
    AppShortcut(
      intent: AskVantaAIIntent(),
      phrases: [
        "Ask \(.applicationName) AI",
        "Open \(.applicationName) AI",
      ],
      shortTitle: "Ask Vanta AI",
      systemImageName: "sparkles"
    )
  }
}
