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
 * Jetpack Glance Widget Receiver for Krivo Daily Question prompt.
 *
 * Registered as `com.personal.couple_app.DailyPromptGlanceWidget` to synchronize
 * with Flutter `HomeWidget.updateWidget(name: 'DailyPromptGlanceWidget', androidName: 'DailyPromptGlanceWidget')`.
 */
class DailyPromptGlanceWidget : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyPromptGlanceWidgetContent()

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
                appWidgetManager.getAppWidgetIds(android.content.ComponentName(context, DailyPromptGlanceWidget::class.java))
            }
            ids.forEach { id ->
                try {
                    val glanceId = glanceManager.getGlanceIdBy(id)
                    glanceAppWidget.update(context, glanceId)
                } catch (e: Throwable) {
                    android.util.Log.e("DailyPromptGlanceWidget", "Error updating widget $id: $e")
                }
            }
        }
    }
}

/**
 * Aesthetic Samsung One UI pastel lavender Glance widget rendering today's daily
 * question prompt and real-time mutual answer reveal status on the Android home screen.
 */
class DailyPromptGlanceWidgetContent : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs: SharedPreferences = try {
            es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        } catch (_: Throwable) {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        }

        // Resilient reading supporting both standard FlutterSharedPreferences prefix and plain keys
        val promptText = prefs.getString("flutter.prompt_text", null)
            ?: prefs.getString("prompt_text", "")
            ?: ""

        val isRevealed = prefs.getBoolean("flutter.is_revealed", false) ||
            prefs.getBoolean("is_revealed", false)

        val isAnsweredByMe = prefs.getBoolean("flutter.is_answered_by_me", false) ||
            prefs.getBoolean("is_answered_by_me", false)

        val savedLocale = prefs.getString("flutter.app_locale", null)
            ?: prefs.getString("app_locale", null)
            ?: prefs.getString("flutter.language", null)
            ?: prefs.getString("language", null)
        val isPt = savedLocale != "en"

        val promptStatus = prefs.getString("flutter.prompt_status", null)
            ?: prefs.getString("prompt_status", null)
            ?: when {
                isRevealed -> if (isPt) "Ambos responderam! 💕" else "Both answered! Tap to read 💕"
                isAnsweredByMe -> if (isPt) "Aguardando seu amor... 🔒" else "Waiting for partner... 🔒"
                else -> if (isPt) "Aguardando sua resposta ✍️" else "Waiting for your answer ✍️"
            }

        val hasPrompt = promptText.isNotBlank()

        provideContent {
            GlanceTheme {
                if (hasPrompt) {
                    PromptCardContent(
                        promptText = promptText,
                        promptStatus = promptStatus,
                        isRevealed = isRevealed,
                        isAnsweredByMe = isAnsweredByMe,
                        isPt = isPt
                    )
                } else {
                    EmptyPromptCard(isPt = isPt)
                }
            }
        }
    }

    @Composable
    private fun PromptCardContent(
        promptText: String,
        promptStatus: String,
        isRevealed: Boolean,
        isAnsweredByMe: Boolean,
        isPt: Boolean
    ) {
        // Dynamic status badge styling
        val badgeBackground = when {
            isRevealed -> Color(0xFFDCFCE7) // Mint
            isAnsweredByMe -> Color(0xFFFEF3C7) // Amber
            else -> Color(0xFFFFE4E6) // Soft Rose
        }

        val badgeTextColor = when {
            isRevealed -> Color(0xFF15803D)
            isAnsweredByMe -> Color(0xFFB45309)
            else -> Color(0xFFBE123C)
        }

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(Color(0xFFFAF5FF))
                .cornerRadius(20.dp)
                .padding(12.dp)
        ) {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.Top,
                horizontalAlignment = Alignment.Start
            ) {
                // Header: Daily question icon & label
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "✨",
                        style = TextStyle(fontSize = 13.sp)
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Text(
                        text = if (isPt) "PERGUNTA DO DIA" else "DAILY QUESTION",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(Color(0xFF7E22CE))
                        )
                    )
                }

                Spacer(modifier = GlanceModifier.height(6.dp))

                // Prompt question body
                Box(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .fillMaxWidth()
                ) {
                    Text(
                        text = "“$promptText”",
                        style = TextStyle(
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(Color(0xFF2E1065))
                        ),
                        maxLines = 4
                    )
                }

                Spacer(modifier = GlanceModifier.height(6.dp))

                // Status Pill Footer
                Box(
                    modifier = GlanceModifier
                        .background(badgeBackground)
                        .cornerRadius(12.dp)
                        .padding(start = 10.dp, top = 4.dp, end = 10.dp, bottom = 4.dp)
                ) {
                    Text(
                        text = promptStatus,
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(badgeTextColor)
                        ),
                        maxLines = 1
                    )
                }
            }
        }
    }

    @Composable
    private fun EmptyPromptCard(isPt: Boolean) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(Color(0xFFFAF5FF))
                .cornerRadius(20.dp)
                .padding(14.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "💭",
                    style = TextStyle(fontSize = 24.sp)
                )
                Spacer(modifier = GlanceModifier.height(6.dp))
                Text(
                    text = if (isPt) "Pergunta do Dia" else "Daily Question",
                    style = TextStyle(
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color(0xFF581C87))
                    )
                )
                Spacer(modifier = GlanceModifier.height(4.dp))
                Text(
                    text = if (isPt) {
                        "Abra o app para responder à pergunta de hoje com seu amor 💕"
                    } else {
                        "Open Krivo to discover today's question for couples 💕"
                    },
                    style = TextStyle(
                        fontSize = 11.sp,
                        color = ColorProvider(Color(0xFF7E22CE))
                    ),
                    maxLines = 2
                )
            }
        }
    }
}
