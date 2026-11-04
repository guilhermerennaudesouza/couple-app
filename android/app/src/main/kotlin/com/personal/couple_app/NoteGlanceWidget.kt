package com.personal.couple_app

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color as AndroidColor
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
import androidx.glance.layout.defaultWeight
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
 * Jetpack Glance Widget Receiver for Krivo shared sticky notes.
 *
 * Registered as `com.personal.couple_app.NoteGlanceWidget` to synchronize
 * with Flutter `HomeWidget.updateWidget(name: 'NoteGlanceWidget', androidName: 'NoteGlanceWidget')`.
 */
class NoteGlanceWidget : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NoteGlanceWidgetContent()
}

/**
 * Aesthetic Jetpack Glance Composable widget rendering a pastel sticky note
 * on the Android home screen with real-time couple data.
 */
class NoteGlanceWidgetContent : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs: SharedPreferences = try {
            es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        } catch (_: Throwable) {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        }

        // Read note attributes supporting both standard FlutterSharedPreferences prefix and plain keys
        val title = prefs.getString("flutter.note_title", null)
            ?: prefs.getString("note_title", "")
            ?: ""

        val content = prefs.getString("flutter.note_content", null)
            ?: prefs.getString("note_content", "")
            ?: ""

        val author = prefs.getString("flutter.note_author", null)
            ?: prefs.getString("note_author", "")
            ?: ""

        val colorHex = prefs.getString("flutter.note_color", null)
            ?: prefs.getString("note_color", "#FFE082")
            ?: "#FFE082"

        val hasNote = content.isNotBlank() || title.isNotBlank()
        val cardColor = parseHexColor(colorHex, defaultColor = Color(0xFFFFE082))

        provideContent {
            GlanceTheme {
                if (hasNote) {
                    NoteCardContent(
                        title = title,
                        content = content,
                        author = author,
                        cardColor = cardColor
                    )
                } else {
                    EmptyNoteCard(cardColor = cardColor)
                }
            }
        }
    }

    @Composable
    private fun NoteCardContent(
        title: String,
        content: String,
        author: String,
        cardColor: Color
    ) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(cardColor)
                .cornerRadius(18.dp)
                .padding(12.dp)
        ) {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.Top,
                horizontalAlignment = Alignment.Start
            ) {
                // Header: Pin icon / Love badge
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "📌",
                        style = TextStyle(
                            fontSize = 14.sp
                        )
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Text(
                        text = if (title.isNotBlank()) title else "Love Note",
                        style = TextStyle(
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(Color(0xFF2E221F))
                        ),
                        maxLines = 1
                    )
                }

                Spacer(modifier = GlanceModifier.height(6.dp))

                // Body: Note content text
                Box(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .fillMaxWidth()
                ) {
                    Text(
                        text = content,
                        style = TextStyle(
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Normal,
                            color = ColorProvider(Color(0xFF3E312D))
                        ),
                        maxLines = 5
                    )
                }

                Spacer(modifier = GlanceModifier.height(6.dp))

                // Footer: Author & heart signature
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.End
                ) {
                    Text(
                        text = if (author.isNotBlank()) "— $author 💕" else "💕",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(Color(0xFF6B5852))
                        ),
                        maxLines = 1
                    )
                }
            }
        }
    }

    @Composable
    private fun EmptyNoteCard(cardColor: Color) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(cardColor)
                .cornerRadius(18.dp)
                .padding(14.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "💌",
                    style = TextStyle(fontSize = 24.sp)
                )
                Spacer(modifier = GlanceModifier.height(6.dp))
                Text(
                    text = "No pinned love note",
                    style = TextStyle(
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color(0xFF2E221F))
                    )
                )
                Spacer(modifier = GlanceModifier.height(4.dp))
                Text(
                    text = "Pin a note from Krivo to see it here 💕",
                    style = TextStyle(
                        fontSize = 11.sp,
                        color = ColorProvider(Color(0xFF6B5852))
                    ),
                    maxLines = 2
                )
            }
        }
    }

    /**
     * Resilient hex color parser supporting 6-character, 8-character, and hash prefixes.
     */
    private fun parseHexColor(hex: String, defaultColor: Color): Color {
        return try {
            val cleanHex = hex.trim().removePrefix("#").removePrefix("0x")
            val colorInt = when (cleanHex.length) {
                6 -> AndroidColor.parseColor("#$cleanHex")
                8 -> AndroidColor.parseColor("#$cleanHex")
                else -> 0xFFFFE082.toInt()
            }
            Color(colorInt)
        } catch (_: Exception) {
            defaultColor
        }
    }
}
