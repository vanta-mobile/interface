package exchange.vanta.app.appfunctions

/**
 * Builds `vantaapp://` navigation links for system agents. The app's deep-link
 * parser stays the single source of validation (markets, increments, user
 * input); this only rejects input an agent can correct immediately and
 * percent-encodes the rest. Nothing here can place an order or sign.
 */
object VantaLinks {
    const val SCHEME = "vantaapp"

    /** Same limit as the app's AI composer; longer prompts are dropped there. */
    const val PROMPT_MAX_LENGTH = 2000

    private val amount = Regex("""^\d+(\.\d+)?$""")

    fun futures(symbol: String?, view: String?, section: String?): String =
        link("futures", "symbol" to symbol, "tab" to view, "panel" to section)

    fun order(symbol: String, type: String, price: String?, quantity: String?, unit: String?): String {
        require(symbol.isNotBlank()) { "symbol is required, for example BTCUSDT or ETH" }
        require(price.isNullOrBlank() || amount.matches(price.trim())) {
            "price must be a plain positive decimal such as 3200.5"
        }
        require(quantity.isNullOrBlank() || amount.matches(quantity.trim())) {
            "quantity must be a plain positive decimal such as 100"
        }
        return link(
            "futures",
            "symbol" to symbol,
            "type" to type,
            // A market order has no limit price.
            "price" to price.takeIf { type != "market" },
            "qty" to quantity,
            "unit" to unit.takeIf { !quantity.isNullOrBlank() },
        )
    }

    fun assistant(prompt: String?): String {
        require((prompt?.trim()?.length ?: 0) <= PROMPT_MAX_LENGTH) {
            "question must be at most $PROMPT_MAX_LENGTH characters"
        }
        return link("assistant", "prompt" to prompt)
    }

    fun page(host: String): String = link(host)

    private fun link(host: String, vararg query: Pair<String, String?>): String {
        val parameters = query.mapNotNull { (key, value) ->
            value?.trim()?.takeIf(String::isNotEmpty)?.let { "$key=${encode(it)}" }
        }
        return "$SCHEME://$host" + if (parameters.isEmpty()) "" else "?" + parameters.joinToString("&")
    }

    /** RFC 3986 percent-encoding of UTF-8; only unreserved characters stay literal. */
    fun encode(value: String): String = buildString {
        for (byte in value.toByteArray(Charsets.UTF_8)) {
            val c = byte.toInt() and 0xff
            val unreserved = c in 'A'.code..'Z'.code || c in 'a'.code..'z'.code ||
                c in '0'.code..'9'.code || c == '-'.code || c == '.'.code || c == '_'.code || c == '~'.code
            if (unreserved) {
                append(c.toChar())
            } else {
                append('%').append(HEX[c shr 4]).append(HEX[c and 0xf])
            }
        }
    }

    private const val HEX = "0123456789ABCDEF"
}
