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
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
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
import java.time.LocalDate
import java.time.temporal.ChronoUnit

private val CoupleWidgetRouteKey = ActionParameters.Key<String>(MainActivity.EXTRA_WIDGET_ROUTE)

/**
 * Jetpack Glance Widget Receiver for Krivo Days Together milestone counter.
 */
class CoupleGlanceWidget : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CoupleGlanceWidgetContent()
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

        val anniversaryIso = prefs.getString("flutter.anniversary", null)
            ?: prefs.getString("anniversary", null)
            ?: ""

        // Compute days together dynamically from saved anniversary ISO date so counter rolls over at midnight
        val dynamicDays: Int? = if (anniversaryIso.length >= 10) {
            try {
                val annivDate = LocalDate.parse(anniversaryIso.substring(0, 10))
                ChronoUnit.DAYS.between(annivDate, LocalDate.now()).coerceAtLeast(0L).toInt()
            } catch (_: Throwable) {
                null
            }
        } else {
            null
        }

        val storedDaysTogether = try {
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

        val daysTogether = dynamicDays ?: storedDaysTogether

        val partnerName = prefs.getString("flutter.partner_name", null)
            ?: prefs.getString("partner_name", null)
            ?: ""

        val savedLocale = prefs.getString("flutter.app_locale", null)
            ?: prefs.getString("app_locale", null)
            ?: prefs.getString("flutter.language", null)
            ?: prefs.getString("language", null)
        val isPt = savedLocale != "en"

        val formattedDays = if (dynamicDays != null) {
            if (isPt) "$dynamicDays dias" else "$dynamicDays days"
        } else {
            prefs.getString("flutter.formatted_days", null)
                ?: prefs.getString("formatted_days", null)
                ?: if (daysTogether > 0) {
                    if (isPt) "$daysTogether dias" else "$daysTogether days"
                } else {
                    if (isPt) "Juntos" else "Together"
                }
        }

        val hasData = anniversaryIso.isNotBlank() ||
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
                .clickable(
                    actionStartActivity<MainActivity>(
                        actionParametersOf(CoupleWidgetRouteKey to "couple")
                    )
                )
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
                .clickable(
                    actionStartActivity<MainActivity>(
                        actionParametersOf(CoupleWidgetRouteKey to "couple")
                    )
                )
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
