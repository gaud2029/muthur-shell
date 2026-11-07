// MU/TH/UR 6000 layout: the header across the top of the window, like
// the lock screen's. The terminal's name on the left, a big clock in the
// middle, the corporation, vessel (host) and crew (user) on the right,
// and a rule underneath whose bright lead-in sweeps back and forth. When
// an agent waits on the person, the header goes to PRIORITY ONE: a red
// alert next to the name (click: go to that agent) and a red rule.

import { View, div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, home, readTextFile, agents, run } from "herdr";

const pad = (n) => String(n).padStart(2, "0");
const DAYS = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
const MONTHS = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST",
  "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"];

export default class Header extends View {
  init(_props, cx) {
    this.host = "UNKNOWN";
    this.crew = (home().split("/").pop() || "UNKNOWN").toUpperCase();
    this.width = 0;
    this.minute = this.stamp();
    cx.spawn(async (cx) => {
      try {
        this.host = (await readTextFile("/etc/hostname")).trim().toUpperCase() || this.host;
      } catch (_e) { /* keep UNKNOWN */ }
      cx.notify();
    });
    // The clock only redraws when the minute turns.
    cx.timer.every(1000, (cx) => {
      const now = this.stamp();
      if (now !== this.minute) { this.minute = now; cx.notify(); }
    });
  }

  stamp() {
    const d = new Date();
    return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()} ${d.getHours()}:${d.getMinutes()}`;
  }

  render() {
    const t = theme();
    const d = new Date();
    const waiting = agents().filter((a) => a.status === "blocked");
    const alarm = waiting.length > 0;
    const rule = alarm ? t.blocked : t.foreground;
    const lead = 160;
    const clock = h_flex().items_center().text_size(30).text_color(t.foreground)
      .child(pad(d.getHours()))
      // The colon breathes like the lock screen's.
      .child(div().loop("opacity", { from: 0.25, to: 1, period: 2000 }).child(":"))
      .child(pad(d.getMinutes()));
    const date = `${DAYS[d.getDay()]} ${pad(d.getDate())} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;

    return v_flex().id("root").size_full().bg(t.chrome).text_color(t.foreground)
      .on_size_change((size, cx) => { this.width = size.width; cx.notify(); })
      .child(h_flex().flex_1().min_h(0).px(22).items_center()
        .child(h_flex().flex_1().min_w(0).gap(18).items_center()
          .child(v_flex().gap(1)
            .child(div().text_size(19).font_bold().child("M U / T H / U R   6 0 0 0"))
            .child(div().text_size(11).text_color(t.muted).child("INTERFACE 2037  ·  MAINFRAME ACCESS")))
          .when(alarm, (el) => el.child(v_flex().id("priority").px(10).py(3).bg(t.blocked).text_color(t.chrome)
            .loop("opacity", { from: 0.55, to: 1, period: 900 })
            .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
            .on_click(() => run("agent.focus", { terminal: waiting[0].address }))
            .child(div().text_size(13).font_bold().child("[ PRIORITY ONE ]"))
            .child(div().text_size(10).child(waiting.length > 1 ? `${waiting.length} CREW AWAITING ORDERS` : "CREW AWAITING ORDERS")))))
        .child(v_flex().flex_none().items_center()
          .child(clock)
          .child(div().text_size(10).text_color(t.muted).child(date)))
        .child(v_flex().flex_1().min_w(0).gap(1).items_end()
          .child(div().text_size(13).child("WEYLAND-YUTANI CORP"))
          .child(div().text_size(11).text_color(t.muted).child(`VESSEL ${this.host}  ·  CREW ${this.crew}`))))
      // The rule, with a bright lead-in sweeping along it.
      .child(div().relative().h(3).mx(22).flex_none()
        .child(div().absolute().left(0).top(1).w_full().h(1).bg(alarm ? t.blocked : t.dim))
        .when(this.width > lead + 44, (el) => el.child(div().absolute().top(0).h(3).w(lead).bg(rule)
          .loop("left", { from: 0, to: this.width - 44 - lead, period: 9000 }))))
      .child(div().h(6).flex_none());
  }
}
