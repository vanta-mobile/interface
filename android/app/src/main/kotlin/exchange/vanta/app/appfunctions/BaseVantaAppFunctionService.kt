package exchange.vanta.app.appfunctions

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint
import androidx.appfunctions.AppFunctionStringValueConstraint
import exchange.vanta.app.MainActivity

/**
 * Navigation functions for Gemini and other system agents. Every function only
 * returns a [PendingIntent] that the user opens; none of them reads account
 * data, places, changes or cancels orders, moves funds or signs anything.
 * The KSP compiler generates the concrete `VantaAppFunctionService`.
 */
@RequiresApi(36)
@AppFunctionServiceEntryPoint(
    serviceName = "VantaAppFunctionService",
    appFunctionXmlFileName = "vanta_app_function_service",
)
abstract class BaseVantaAppFunctionService : AppFunctionService() {
    /**
     * Opens the Vanta perpetual futures page, optionally on a market and section.
     * Use this for viewing a market, its chart, the user's open orders or positions.
     *
     * @param symbol USDT-margined perpetual such as BTCUSDT; a bare asset such as ETH also works. Omit to keep the current market. Unknown markets keep the current market.
     * @param view Which workspace to show: "trade" for the order form and order book, "chart" for the candlestick chart.
     * @param section Account section below the form: "orders" for open orders, "positions" for open positions, "assets" for futures account assets.
     * @return A [PendingIntent] that opens the page in Vanta when the user taps it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun openFutures(
        symbol: String? = null,
        @AppFunctionStringValueConstraint(enumValues = ["trade", "chart"])
        view: String? = null,
        @AppFunctionStringValueConstraint(enumValues = ["orders", "positions", "assets"])
        section: String? = null,
    ): PendingIntent = open(VantaLinks.futures(symbol, view, section))

    /**
     * Opens the futures order form with suggested inputs filled in. This never places an order:
     * the user still chooses Long or Short, reviews a confirmation and signs with their wallet.
     * Inputs the user has already typed are kept; values off the market's price or size increment are dropped, never rounded.
     *
     * @param symbol USDT-margined perpetual such as BTCUSDT, or a bare asset such as ETH.
     * @param orderType "limit" or "market".
     * @param price Limit price as a plain decimal such as 3200.5. Ignored for market orders.
     * @param quantity Order size as a plain decimal such as 100.
     * @param quantityUnit "quote" when quantity is in USDT (default), "base" when it is in the asset, such as BTC.
     * @return A [PendingIntent] that opens the prefilled order form in Vanta when the user taps it.
     * @throws AppFunctionInvalidArgumentException If symbol is blank or price or quantity is not a plain positive decimal. Ask the user to restate the value.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun prepareFuturesOrder(
        symbol: String,
        @AppFunctionStringValueConstraint(enumValues = ["limit", "market"])
        orderType: String,
        price: String? = null,
        quantity: String? = null,
        @AppFunctionStringValueConstraint(enumValues = ["quote", "base"])
        quantityUnit: String? = null,
    ): PendingIntent = open(checked { VantaLinks.order(symbol, orderType, price, quantity, quantityUnit) })

    /**
     * Opens the user's Vanta portfolio: balances, asset distribution and profit and loss.
     *
     * @return A [PendingIntent] that opens the portfolio in Vanta when the user taps it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun openPortfolio(): PendingIntent = open(VantaLinks.page("portfolio"))

    /**
     * Opens Vanta points: the user's points, activities and tasks.
     *
     * @return A [PendingIntent] that opens points in Vanta when the user taps it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun openPoints(): PendingIntent = open(VantaLinks.page("points"))

    /**
     * Opens the Vanta notification inbox: fills, order updates, liquidation and margin alerts, transfers and announcements.
     *
     * @return A [PendingIntent] that opens the inbox in Vanta when the user taps it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun openNotifications(): PendingIntent = open(VantaLinks.page("notifications"))

    /**
     * Opens Vanta AI, the in-app trading assistant, optionally with a question typed into its input.
     * The question is not sent until the user sends it.
     *
     * @param question Question to place in the input, at most 2000 characters.
     * @return A [PendingIntent] that opens Vanta AI when the user taps it.
     * @throws AppFunctionInvalidArgumentException If the question is longer than 2000 characters. Ask the user to shorten it.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun askVantaAi(question: String? = null): PendingIntent =
        open(checked { VantaLinks.assistant(question) })

    private inline fun checked(build: () -> String): String =
        try {
            build()
        } catch (e: IllegalArgumentException) {
            throw AppFunctionInvalidArgumentException(e.message ?: "Invalid argument")
        }

    /** Explicit to MainActivity: `vanta://` belongs to Privy, `vantaapp://` only to the app. */
    private fun open(link: String): PendingIntent =
        PendingIntent.getActivity(
            this,
            link.hashCode(),
            Intent(Intent.ACTION_VIEW, Uri.parse(link), this, MainActivity::class.java),
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
        )
}
