package com.personal.couple_app

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

/**
 * Jetpack Glance Widget Receiver for Krivo Days Together milestone counter.
 *
 * Registered as `com.personal.couple_app.CoupleGlanceWidget` to synchronize
 * with Flutter `HomeWidget.updateWidget(name: 'CoupleGlanceWidget', androidName: 'CoupleGlanceWidget')`.
 */
class CoupleGlanceWidget : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CoupleGlanceWidgetContent()

    override fun onUpdate(
        context: Context,
        appWidgetManager: android.appwidget.AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        kotlinx.coroutines.runBlocking {
            val glanceManager = androidx.glance.appwidget.GlanceAppWidgetManager(context)
            val ids = if (appWidgetIds.isNotEmpty()) {
                appWidgetIds
            } else {
                appWidgetManager.getAppWidgetIds(android.content.ComponentName(context, CoupleGlanceWidget::class.java))
            }
            ids.forEach { id ->
                try {
                    val glanceId = glanceManager.getGlanceIdBy(id)
                    glanceAppWidget.update(context, glanceId)
                } catch (e: Throwable) {
                    android.util.Log.e("CoupleGlanceWidget", "Error updating widget $id: $e")
                }
            }
        }
    }
}

/**
 * Aesthetic Samsung One UI romantic rose Glance widget rendering the couple's
 * anniversary days count, partner name, and love badge on the Android home screen.
 */
class CoupleGlanceWidgetContent : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs: SharedPreferences = try {
            es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        } catch (_: Throwable) {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        }

        // Resilient reading supporting both standard FlutterSharedPreferences prefix and plain keys
        val daysTogether = try {
            val fVal = prefs.getInt("flutter.days_together", -1)
            if (fVal != -1) fVal else {
                val pVal = prefs.getInt("days_together", -1)
                if (pVal != -1) pVal else {
                    prefs.getString("flutter.days_together", null)?.toIntOrNull()
                        ?: prefs.getString("days_together", null)?.toIntOrNull()
                        ?: 0
                }
            }
        } catch (_: Throwable) {
            try {
                val fLong = prefs.getLong("flutter.days_together", -1L)
                if (fLong != -1L) fLong.toInt() else prefs.getLong("days_together", 0L).toInt()
            } catch (_: Throwable) {
                0
            }
        }

        val partnerName = prefs.getString("flutter.partner_name", null)
            ?: prefs.getString("partner_name", null)
            ?: ""

        val savedLocale = prefs.getString("flutter.app_locale", null)
            ?: prefs.getString("app_locale", null)
            ?: prefs.getString("flutter.language", null)
            ?: prefs.getString("language", null)
        val isPt = savedLocale != "en"

        val formattedDays = prefs.getString("flutter.formatted_days", null)
            ?: prefs.getString("formatted_days", null)
            ?: if (daysTogether > 0) {
                if (isPt) "$daysTogether dias" else "$daysTogether days"
            } else {
                if (isPt) "Juntos" else "Together"
            }

        val hasData = prefs.contains("flutter.days_together") ||
            prefs.contains("days_together") ||
            prefs.contains("flutter.anniversary") ||
            prefs.contains("anniversary") ||
            daysTogether > 0 ||
            partnerName.isNotBlank()

        provideContent {
            GlanceTheme {
                if (hasData) {
                    CoupleCardContent(
                        daysTogether = daysTogether,
                        partnerName = partnerName,
                        formattedDays = formattedDays,
                        isPt = isPt
                    )
                } else {
                    EmptyCoupleCard(isPt = isPt)
                }
            }
        }
    }

    @Composable
    private fun CoupleCardContent(
        daysTogether: Int,
        partnerName: String,
        formattedDays: String,
        isPt: Boolean
    ) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(Color(0xFFFFF0F3))
                .cornerRadius(20.dp)
                .padding(12.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Header badge: Romantic heart icon and title
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "❤️",
                        style = TextStyle(fontSize = 13.sp)
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Text(
                        text = if (isPt) "DIAS JUNTOS" else "DAYS TOGETHER",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(Color(0xFFB55D70))
                        )
                    )
                }

                Spacer(modifier = GlanceModifier.height(4.dp))

                // Hero counter: Days together number
                Text(
                    text = "$daysTogether",
                    style = TextStyle(
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color(0xFF8B263E))
                    ),
                    maxLines = 1
                )

                Text(
                    text = if (isPt) {
                        if (daysTogether == 1) "dia de amor" else "dias de amor"
                    } else {
                        if (daysTogether == 1) "day in love" else "days in love"
                    },
                    style = TextStyle(
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = ColorProvider(Color(0xFF9E4758))
                    ),
                    maxLines = 1
                )

                Spacer(modifier = GlanceModifier.height(8.dp))

                // Partner pill footer
                Box(
                    modifier = GlanceModifier
                        .background(Color(0xFFFFD9E2))
                        .cornerRadius(12.dp)
                        .padding(start = 10.dp, top = 4.dp, end = 10.dp, bottom = 4.dp)
                ) {
                    val partnerText = if (partnerName.isNotBlank()) {
                        if (isPt) "Com $partnerName 💕" else "With $partnerName 💕"
                    } else {
                        if (isPt) "Para Sempre Juntos 💕" else "Forever & Always 💕"
                    }
                    Text(
                        text = partnerText,
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(Color(0xFF6B1D2F))
                        ),
                        maxLines = 1
                    )
                }
            }
        }
    }

    @Composable
    private fun EmptyCoupleCard(isPt: Boolean) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(Color(0xFFFFF0F3))
                .cornerRadius(20.dp)
                .padding(14.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "💖",
                    style = TextStyle(fontSize = 24.sp)
                )
                Spacer(modifier = GlanceModifier.height(6.dp))
                Text(
                    text = if (isPt) "Dias Juntos" else "Days Together",
                    style = TextStyle(
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color(0xFF8B263E))
                    )
                )
                Spacer(modifier = GlanceModifier.height(4.dp))
                Text(
                    text = if (isPt) {
                        "Defina seu aniversário no app para iniciar o contador 💕"
                    } else {
                        "Set your anniversary in Krivo to start your counter 💕"
                    },
                    style = TextStyle(
                        fontSize = 11.sp,
                        color = ColorProvider(Color(0xFF9E4758))
                    ),
                    maxLines = 2
                )
            }
        }
    }
}
