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
 * Jetpack Glance Widget Receiver for Krivo shared couple tasks and chores.
 *
 * Registered as `com.personal.couple_app.TasksGlanceWidget` to synchronize
 * with Flutter `HomeWidget.updateWidget(name: 'TasksGlanceWidget', androidName: 'TasksGlanceWidget')`.
 */
class TasksGlanceWidget : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TasksGlanceWidgetContent()

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
                appWidgetManager.getAppWidgetIds(android.content.ComponentName(context, TasksGlanceWidget::class.java))
            }
            ids.forEach { id ->
                try {
                    val glanceId = glanceManager.getGlanceIdBy(id)
                    glanceAppWidget.update(context, glanceId)
                } catch (e: Throwable) {
                    android.util.Log.e("TasksGlanceWidget", "Error updating widget $id: $e")
                }
            }
        }
    }
}

/**
 * Aesthetic Samsung One UI pastel mint Glance widget rendering the top 3 shared
 * couple tasks, completion status indicators, and remaining pending chores badge.
 */
class TasksGlanceWidgetContent : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs: SharedPreferences = try {
            es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        } catch (_: Throwable) {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        }

        // Resilient reading supporting both standard FlutterSharedPreferences prefix and plain keys
        val task1Title = prefs.getString("flutter.task_1_title", null)
            ?: prefs.getString("task_1_title", "")
            ?: ""
        val task1Done = prefs.getBoolean("flutter.task_1_done", false) ||
            prefs.getBoolean("task_1_done", false)

        val task2Title = prefs.getString("flutter.task_2_title", null)
            ?: prefs.getString("task_2_title", "")
            ?: ""
        val task2Done = prefs.getBoolean("flutter.task_2_done", false) ||
            prefs.getBoolean("task_2_done", false)

        val task3Title = prefs.getString("flutter.task_3_title", null)
            ?: prefs.getString("task_3_title", "")
            ?: ""
        val task3Done = prefs.getBoolean("flutter.task_3_done", false) ||
            prefs.getBoolean("task_3_done", false)

        val remainingCount = try {
            val fVal = prefs.getInt("flutter.remaining_tasks_count", -1)
            if (fVal != -1) fVal else prefs.getInt("remaining_tasks_count", 0)
        } catch (_: Throwable) {
            0
        }

        val savedLocale = prefs.getString("flutter.app_locale", null)
            ?: prefs.getString("app_locale", null)
            ?: prefs.getString("flutter.language", null)
            ?: prefs.getString("language", null)
        val isPt = savedLocale != "en"

        val hasTasks = task1Title.isNotBlank() || task2Title.isNotBlank() || task3Title.isNotBlank()

        provideContent {
            GlanceTheme {
                if (hasTasks) {
                    TasksCardContent(
                        task1Title = task1Title,
                        task1Done = task1Done,
                        task2Title = task2Title,
                        task2Done = task2Done,
                        task3Title = task3Title,
                        task3Done = task3Done,
                        remainingCount = remainingCount,
                        isPt = isPt
                    )
                } else {
                    EmptyTasksCard(isPt = isPt)
                }
            }
        }
    }

    @Composable
    private fun TasksCardContent(
        task1Title: String,
        task1Done: Boolean,
        task2Title: String,
        task2Done: Boolean,
        task3Title: String,
        task3Done: Boolean,
        remainingCount: Int,
        isPt: Boolean
    ) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(Color(0xFFF0FDF4))
                .cornerRadius(20.dp)
                .padding(12.dp)
        ) {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.Top,
                horizontalAlignment = Alignment.Start
            ) {
                // Header: Title and optional remaining count badge
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "☑️",
                        style = TextStyle(fontSize = 13.sp)
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Text(
                        text = if (isPt) "TAREFAS DO CASAL" else "COUPLE TASKS",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(Color(0xFF15803D))
                        )
                    )

                    if (remainingCount > 0) {
                        Spacer(modifier = GlanceModifier.defaultWeight())
                        Box(
                            modifier = GlanceModifier
                                .background(Color(0xFFDCFCE7))
                                .cornerRadius(10.dp)
                                .padding(start = 6.dp, top = 2.dp, end = 6.dp, bottom = 2.dp)
                        ) {
                            Text(
                                text = if (isPt) "+$remainingCount mais" else "+$remainingCount more",
                                style = TextStyle(
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = ColorProvider(Color(0xFF166534))
                                )
                            )
                        }
                    }
                }

                Spacer(modifier = GlanceModifier.height(8.dp))

                // Task Checklist Rows
                Column(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (task1Title.isNotBlank()) {
                        TaskRow(title = task1Title, isDone = task1Done)
                    }

                    if (task2Title.isNotBlank()) {
                        Spacer(modifier = GlanceModifier.height(6.dp))
                        TaskRow(title = task2Title, isDone = task2Done)
                    }

                    if (task3Title.isNotBlank()) {
                        Spacer(modifier = GlanceModifier.height(6.dp))
                        TaskRow(title = task3Title, isDone = task3Done)
                    }
                }

                Spacer(modifier = GlanceModifier.height(4.dp))

                // Footer hint
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.End
                ) {
                    Text(
                        text = if (isPt) "Toque para abrir o app 💕" else "Tap to open Krivo 💕",
                        style = TextStyle(
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Normal,
                            color = ColorProvider(Color(0xFF166534))
                        ),
                        maxLines = 1
                    )
                }
            }
        }
    }

    @Composable
    private fun TaskRow(
        title: String,
        isDone: Boolean
    ) {
        val checkIcon = if (isDone) "✓" else "○"
        val checkColor = if (isDone) Color(0xFF16A34A) else Color(0xFF94A3B8)
        val titleColor = if (isDone) Color(0xFF64748B) else Color(0xFF1E293B)

        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = checkIcon,
                style = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(checkColor)
                )
            )
            Spacer(modifier = GlanceModifier.width(8.dp))
            Text(
                text = title,
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(
                    fontSize = 12.sp,
                    fontWeight = if (isDone) FontWeight.Normal else FontWeight.Medium,
                    color = ColorProvider(titleColor)
                ),
                maxLines = 1
            )
        }
    }

    @Composable
    private fun EmptyTasksCard(isPt: Boolean) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(8.dp)
                .background(Color(0xFFF0FDF4))
                .cornerRadius(20.dp)
                .padding(14.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "🎉",
                    style = TextStyle(fontSize = 24.sp)
                )
                Spacer(modifier = GlanceModifier.height(6.dp))
                Text(
                    text = if (isPt) "Todas as tarefas concluídas!" else "All Tasks Completed!",
                    style = TextStyle(
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color(0xFF15803D))
                    )
                )
                Spacer(modifier = GlanceModifier.height(4.dp))
                Text(
                    text = if (isPt) {
                        "Nenhum afazer pendente. Aproveitem o momento juntos 💕"
                    } else {
                        "No pending chores. Relax and enjoy your time together 💕"
                    },
                    style = TextStyle(
                        fontSize = 11.sp,
                        color = ColorProvider(Color(0xFF166534))
                    ),
                    maxLines = 2
                )
            }
        }
    }
}
