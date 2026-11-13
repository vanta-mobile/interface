package exchange.vanta.app.appfunctions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * The same literal links are parsed in test/features/deep_link/agent_links_test.dart,
 * so the Kotlin builder and the Dart parser cannot drift apart unnoticed.
 */
class VantaLinksTest {
    @Test
    fun futuresLinksCarryOnlyGivenParameters() {
        assertEquals(
            "vantaapp://futures?symbol=ETH&tab=chart&panel=positions",
            VantaLinks.futures("ETH", "chart", "positions"),
        )
        assertEquals("vantaapp://futures", VantaLinks.futures(null, " ", null))
        assertEquals("vantaapp://portfolio", VantaLinks.page("portfolio"))
    }

    @Test
    fun orderLinksPrefillWithoutPriceForMarketOrders() {
        assertEquals(
            "vantaapp://futures?symbol=BTCUSDT&type=limit&price=3200.5&qty=100&unit=quote",
            VantaLinks.order("BTCUSDT", "limit", "3200.5", "100", "quote"),
        )
        assertEquals(
            "vantaapp://futures?symbol=BTC&type=market&qty=0.01&unit=base",
            VantaLinks.order("BTC", "market", "3000", "0.01", "base"),
        )
        assertEquals(
            "vantaapp://futures?symbol=ETH&type=limit",
            VantaLinks.order("ETH", "limit", null, null, "base"),
        )
    }

    @Test
    fun promptsArePercentEncodedAsUtf8() {
        assertEquals(
            "vantaapp://assistant?prompt=%E5%88%86%E6%9E%90%20BTC%20%E8%A1%8C%E6%83%85%20%26%20%E9%A3%8E%E9%99%A9%3F",
            VantaLinks.assistant("分析 BTC 行情 & 风险?"),
        )
        assertEquals("vantaapp://assistant", VantaLinks.assistant(null))
    }

    @Test
    fun rejectsInputAnAgentShouldRestate() {
        for (call in listOf<() -> Unit>(
            { VantaLinks.order(" ", "limit", null, "1", "quote") },
            { VantaLinks.order("BTC", "limit", "1e3", null, null) },
            { VantaLinks.order("BTC", "limit", "1,000", null, null) },
            { VantaLinks.order("BTC", "market", null, "-1", "quote") },
            { VantaLinks.assistant("a".repeat(VantaLinks.PROMPT_MAX_LENGTH + 1)) },
        )) {
            assertThrows(IllegalArgumentException::class.java) { call() }
        }
    }
}
