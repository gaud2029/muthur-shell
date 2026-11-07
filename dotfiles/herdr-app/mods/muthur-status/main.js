// MU/TH/UR 6000 layout: the status line along the bottom, like the lock
// screen's. Power as a block bar (green to red, or AUX SUPPLY without a
// battery), a line of drifting hex in the middle (nothing, but alive),
// and the crew count, who's waiting and the uptime on the right.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { agents, theme, readTextFile, run } from "herdr";

const pad = (n) => String(n).padStart(2, "0");
const word = () => Math.floor(Math.random() * 65536).toString(16).toUpperCase().padStart(4, "0");

export default class Status extends View {
  init(_props, cx) {
    this.charge = null;
    this.uptime = "";
    // The hex stream's frames are made once; .frames() plays them natively.
    this.stream = Array.from({ length: 48 }, () => Array.from({ length: 6 }, word).join(" "));
    this.refresh(cx);
    cx.timer.every(60000, (cx) => this.refresh(cx));
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      this.charge = null;
      for (const bat of ["BAT0", "BAT1", "BAT2"]) {
        try {
          this.charge = parseInt(await readTextFile(`/sys/class/power_supply/${bat}/capacity`), 10);
          break;
        } catch (_e) { /* next */ }
      }
      try {
        const s = Math.floor(parseFloat(await readTextFile("/proc/uptime")) || 0);
        const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        this.uptime = (d > 0 ? `${d}D ` : "") + `${pad(h)}H ${pad(m)}M`;
      } catch (_e) { this.uptime = ""; }
      cx.notify();
    });
  }

  render() {
    const t = theme();
    const crew = agents();
    const active = crew.filter((a) => a.status === "working").length;
    const waiting = crew.filter((a) => a.status === "blocked").length;
    const c = this.charge;
    const has = Number.isFinite(c);
    const level = !has ? t.foreground : c > 50 ? t.ansi2 : c > 20 ? t.ansi3 : t.ansi1;

    return h_flex().size_full().px(14).gap(16).items_center().bg(t.chrome).border_t(1).border_color(t.dim)
      .text_size(11).text_color(t.foreground)
      .child(h_flex().flex_none().gap(8).items_center().text_color(level)
        .child(has ? `POW ${String(c).padStart(3, "0")}%` : "POW  AUX SUPPLY")
        // Ten cells, filled by tenths, like the lock screen's bar.
        .when(has, (el) => el.child(h_flex().gap(2).children(Array.from({ length: 10 }, (_, i) =>
          div().w(6).h(9).border(1).border_color(level).when(i < Math.round(c / 10), (d) => d.bg(level)))))))
      .child(div().flex_1().min_w(0).flex().justify_center().overflow_hidden()
        .child(div().text_color(t.dim).frames(this.stream, 160).child(this.stream[0])))
      .when(waiting > 0, (el) => el.child(div().flex_none().text_color(t.blocked)
        .loop("opacity", { from: 0.35, to: 1, period: 900 }).child(`${waiting} AWAITING ORDERS`)))
      .child(div().id("st-crew").flex_none().hover((s) => s.text_color(t.accent)).on_click(() => run("agent.next"))
        .child(`CREW ${pad(crew.length)}  ·  ACTIVE ${pad(active)}`))
      .when(Boolean(this.uptime), (el) => el.child(div().flex_none().text_color(t.muted).child(`UPTIME ${this.uptime}`)));
  }
}
