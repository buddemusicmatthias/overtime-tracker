"""NiceGUI dashboard for overtime visualization. Runs as a separate process."""

import csv
import io
from datetime import date, datetime, timedelta

from nicegui import ui

from src.config import config
from src.database import (
    get_daily_summary,
    get_week_summaries,
    get_app_summaries,
    get_monthly_summaries,
    export_csv,
    update_daily_summaries,
)


def format_minutes(minutes: float) -> str:
    """Format minutes as 'Xh Ym'."""
    h = int(minutes // 60)
    m = int(minutes % 60)
    return f"{h}h {m}m"


DAY_NAMES = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
CATEGORY_COLORS = {
    "regular": "#4CAF50",
    "overtime": "#F44336",
    "friday": "#FF9800",
}


@ui.page("/")
def index():
    ui.query("body").classes("bg-gray-50")

    with ui.header().classes("bg-blue-800 text-white"):
        ui.label("Overtime Tracker").classes("text-2xl font-bold")
        ui.space()
        today = date.today()
        ui.label(today.strftime("%A, %d. %B %Y")).classes("text-sm opacity-80")

    with ui.tabs().classes("w-full bg-white") as tabs:
        tab_day = ui.tab("Today")
        tab_week = ui.tab("Week")
        tab_month = ui.tab("Month")
        tab_export = ui.tab("Export")

    with ui.tab_panels(tabs, value=tab_day).classes("w-full max-w-6xl mx-auto"):
        with ui.tab_panel(tab_day):
            build_day_view()
        with ui.tab_panel(tab_week):
            build_week_view()
        with ui.tab_panel(tab_month):
            build_month_view()
        with ui.tab_panel(tab_export):
            build_export_view()


def build_day_view():
    """Today's overview with key metrics and app breakdown."""
    today_str = date.today().isoformat()

    # Force summary update
    update_daily_summaries(today_str)
    summary = get_daily_summary(today_str)
    apps = get_app_summaries(today_str)

    if not summary:
        ui.label("No data recorded today yet.").classes("text-gray-500 text-lg p-8")
        return

    # Key metrics cards
    with ui.row().classes("w-full gap-4 p-4"):
        _metric_card("Active Time", format_minutes(summary.total_active_minutes), "bg-blue-100")
        _metric_card("Overtime", format_minutes(summary.overtime_minutes), "bg-red-100")
        _metric_card("Idle Time", format_minutes(summary.total_idle_minutes), "bg-gray-100")
        _metric_card(
            "First / Last",
            f"{summary.first_activity or '—'} – {summary.last_activity or '—'}",
            "bg-green-100",
        )

    # App breakdown chart
    if apps:
        ui.label("App Breakdown").classes("text-lg font-semibold px-4 pt-4")
        app_names = [a.app_name for a in apps[:10]]  # Top 10
        app_minutes = [round(a.active_minutes, 1) for a in apps[:10]]

        ui.echart({
            "xAxis": {"type": "value", "name": "Minutes"},
            "yAxis": {"type": "category", "data": list(reversed(app_names)), "inverse": False},
            "series": [{"type": "bar", "data": list(reversed(app_minutes)), "color": "#3B82F6"}],
            "tooltip": {"trigger": "axis"},
            "grid": {"left": "20%", "right": "10%"},
        }).classes("w-full h-80")

        # Also show as table
        columns = [
            {"name": "app", "label": "App", "field": "app", "align": "left"},
            {"name": "time", "label": "Time", "field": "time", "align": "right"},
            {"name": "pct", "label": "%", "field": "pct", "align": "right"},
        ]
        total = sum(a.active_minutes for a in apps)
        rows = [
            {
                "app": a.app_name,
                "time": format_minutes(a.active_minutes),
                "pct": f"{(a.active_minutes / total * 100):.0f}%" if total > 0 else "0%",
            }
            for a in apps
        ]
        ui.table(columns=columns, rows=rows, row_key="app").classes("w-full px-4")


def build_week_view():
    """Current week overview with daily bars."""
    now = datetime.now()
    iso_year, iso_week, _ = now.isocalendar()

    # Update summaries for the whole week
    monday = date.fromisocalendar(iso_year, iso_week, 1)
    for i in range(7):
        d = monday + timedelta(days=i)
        if d <= date.today():
            update_daily_summaries(d.isoformat())

    week_data = get_week_summaries(iso_year, iso_week)

    if not week_data:
        ui.label("No data for this week yet.").classes("text-gray-500 text-lg p-8")
        return

    total_active = sum(d.total_active_minutes for d in week_data)
    total_overtime = sum(d.overtime_minutes for d in week_data)
    target_minutes = config.schedule.weekly_target_hours * 60

    # Summary cards
    with ui.row().classes("w-full gap-4 p-4"):
        _metric_card("Total Active", format_minutes(total_active), "bg-blue-100")
        _metric_card("Total Overtime", format_minutes(total_overtime), "bg-red-100")
        _metric_card(
            "vs Target (32h)",
            f"{'+' if total_active > target_minutes else ''}{format_minutes(total_active - target_minutes)}",
            "bg-yellow-100",
        )

    # Daily breakdown chart
    days = [DAY_NAMES[d.day_of_week] for d in week_data]
    regular = [round(max(0, d.total_active_minutes - d.overtime_minutes), 1) for d in week_data]
    overtime = [round(d.overtime_minutes, 1) for d in week_data]

    ui.label("Daily Breakdown").classes("text-lg font-semibold px-4 pt-4")
    ui.echart({
        "xAxis": {"type": "category", "data": days},
        "yAxis": {"type": "value", "name": "Minutes"},
        "legend": {"data": ["Regular", "Overtime"]},
        "series": [
            {"name": "Regular", "type": "bar", "stack": "total", "data": regular, "color": "#4CAF50"},
            {"name": "Overtime", "type": "bar", "stack": "total", "data": overtime, "color": "#F44336"},
        ],
        "tooltip": {"trigger": "axis"},
    }).classes("w-full h-80")

    # Daily detail table
    columns = [
        {"name": "day", "label": "Day", "field": "day", "align": "left"},
        {"name": "category", "label": "Category", "field": "category", "align": "center"},
        {"name": "active", "label": "Active", "field": "active", "align": "right"},
        {"name": "overtime", "label": "Overtime", "field": "overtime", "align": "right"},
        {"name": "span", "label": "Time Span", "field": "span", "align": "right"},
    ]
    rows = [
        {
            "day": f"{DAY_NAMES[d.day_of_week]} ({d.date})",
            "category": d.work_category,
            "active": format_minutes(d.total_active_minutes),
            "overtime": format_minutes(d.overtime_minutes),
            "span": f"{d.first_activity or '—'} – {d.last_activity or '—'}",
        }
        for d in week_data
    ]
    ui.table(columns=columns, rows=rows, row_key="day").classes("w-full px-4")


def build_month_view():
    """Monthly cumulative overtime view."""
    today = date.today()
    month_data = get_monthly_summaries(today.year, today.month)

    if not month_data:
        ui.label("No data for this month yet.").classes("text-gray-500 text-lg p-8")
        return

    total_overtime = sum(d.overtime_minutes for d in month_data)
    total_active = sum(d.total_active_minutes for d in month_data)
    days_worked = len([d for d in month_data if d.total_active_minutes > 0])

    with ui.row().classes("w-full gap-4 p-4"):
        _metric_card("Monthly Overtime", format_minutes(total_overtime), "bg-red-100")
        _metric_card("Monthly Active", format_minutes(total_active), "bg-blue-100")
        _metric_card("Days Worked", str(days_worked), "bg-green-100")

    # Cumulative overtime trend
    cumulative = []
    running_total = 0.0
    dates = []
    for d in month_data:
        running_total += d.overtime_minutes
        cumulative.append(round(running_total / 60, 1))  # in hours
        dates.append(d.date[5:])  # MM-DD

    ui.label("Cumulative Overtime (hours)").classes("text-lg font-semibold px-4 pt-4")
    ui.echart({
        "xAxis": {"type": "category", "data": dates},
        "yAxis": {"type": "value", "name": "Hours"},
        "series": [{
            "type": "line",
            "data": cumulative,
            "smooth": True,
            "areaStyle": {"color": "rgba(244,67,54,0.15)"},
            "color": "#F44336",
        }],
        "tooltip": {"trigger": "axis"},
    }).classes("w-full h-64")

    # Daily bars for the month
    day_labels = [d.date[5:] for d in month_data]
    overtime_vals = [round(d.overtime_minutes, 1) for d in month_data]
    colors = [CATEGORY_COLORS.get(d.work_category, "#999") for d in month_data]

    ui.label("Daily Overtime (minutes)").classes("text-lg font-semibold px-4 pt-4")
    ui.echart({
        "xAxis": {"type": "category", "data": day_labels},
        "yAxis": {"type": "value", "name": "Minutes"},
        "series": [{
            "type": "bar",
            "data": [{"value": v, "itemStyle": {"color": c}} for v, c in zip(overtime_vals, colors)],
        }],
        "tooltip": {"trigger": "axis"},
    }).classes("w-full h-64")


def build_export_view():
    """CSV export with date range selection."""
    today = date.today()
    month_start = today.replace(day=1)

    ui.label("Export Activity Data").classes("text-lg font-semibold p-4")

    start_ref = {"value": month_start.isoformat()}
    end_ref = {"value": today.isoformat()}

    with ui.row().classes("gap-4 px-4 items-end"):
        with ui.column():
            ui.label("Start Date")
            start_input = ui.input("Start", value=month_start.isoformat()).props("type=date")
            start_input.on_value_change(lambda e: start_ref.update({"value": e.value}))
        with ui.column():
            ui.label("End Date")
            end_input = ui.input("End", value=today.isoformat()).props("type=date")
            end_input.on_value_change(lambda e: end_ref.update({"value": e.value}))

        async def do_export():
            rows = export_csv(start_ref["value"], end_ref["value"])
            if not rows:
                ui.notify("No data in selected range", type="warning")
                return
            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
            content = output.getvalue()
            filename = f"overtime_{start_ref['value']}_to_{end_ref['value']}.csv"
            ui.download(content.encode(), filename)

        ui.button("Export CSV", on_click=do_export, icon="download").props("color=primary")


def _metric_card(title: str, value: str, bg_class: str):
    """Render a small metric card."""
    with ui.card().classes(f"p-4 {bg_class} min-w-48"):
        ui.label(title).classes("text-xs text-gray-600 uppercase tracking-wider")
        ui.label(value).classes("text-xl font-bold mt-1")


def main():
    """Run the dashboard as a standalone NiceGUI app."""
    ui.run(
        port=config.dashboard_port,
        title="Overtime Tracker",
        reload=False,
        show=False,
    )


if __name__ == "__main__":
    main()
