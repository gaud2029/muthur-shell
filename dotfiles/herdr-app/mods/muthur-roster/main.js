// MU/TH/UR 6000 layout: the sidebar. Framed panels with their label on
// the top edge, like the lock screen's [ PRIORITY ONE ]: SECTORS (the
// spaces), CREW (the agents, with what each is doing in words) and
// SYSTEM. The selected row inverts like the shell's buttons. At the
// bottom, the Nostromo's wireframe descent from the lock screen.

import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { spaces, agents, run, theme, openOverlay, setAgentOrder, layouts, shared } from "herdr";

const pad = (n) => String(n).padStart(2, "0");

// A scanner: a block sweeping back and forth in a frame, natively (block
// characters like ░▒▓ fall back to another font in the panels).
function scanner(color, w = 34) {
  return div().relative().flex_none().w(w).h(8).border(1).border_color(color)
    .child(div().absolute().top(1).left(1).h(4).w(8).bg(color).loop("left", { from: 1, to: w - 11, period: 1100 }));
}

const WORDS = { working: "WORKING", blocked: "AWAITING ORDERS", done: "TASK COMPLETE", idle: "STANDING BY" };

// A panel framed in a line, its [ LABEL ] cut into the top edge: the top
// edge is drawn in pieces (corner, label, line, extra, corner) at the
// label's middle, the rest of the frame is the body's border.
function frame(t, label, body, extra, grow = false) {
  const edge = (el) => el.h(8).mt(8).border_t(1).border_color(t.dim);
  return v_flex().mt(6).when(grow, (el) => el.flex_1().min_h(0)).when(!grow, (el) => el.flex_none())
    .child(h_flex().h(16).flex_none().items_start()
      .child(edge(div().w(10).flex_none().border_l(1)))
      .child(div().h(16).px(6).flex().items_center().text_size(11).text_color(t.foreground).child(`[ ${label} ]`))
      .child(edge(div().flex_1()))
      .when(Boolean(extra), (el) => el.child(extra))
      .child(edge(div().w(10).flex_none().border_r(1))))
    .child(v_flex().when(grow, (el) => el.flex_1().min_h(0)).border_l(1).border_r(1).border_b(1).border_color(t.dim).pt(4).pb(6).child(body));
}

function statusMark(t, status, inverted) {
  const fg = inverted ? t.chrome : null;
  if (status === "working")
    return scanner(fg ?? t.working);
  if (status === "blocked")
    return div().flex_none().text_color(fg ?? t.blocked).loop("opacity", { from: 0.3, to: 1, period: 900 }).child("!! ");
  if (status === "done")
    return div().flex_none().text_color(fg ?? t.done).child("■ OK");
  return null;
}

const clock = () => { const d = new Date(); return `${pad(d.getHours())}:${pad(d.getMinutes())}`; };
const agentName = (a) => `${(a.program?.name ?? a.app ?? "AGENT").toUpperCase()} CH.${pad(a.tab_index)}`;
const EVENTS = { working: "WORKING.", blocked: "AWAITING ORDERS.", done: "TASK COMPLETE." };

export default class Roster extends View {
  init(_props, cx) {
    // The console: lines MU/TH/UR types out one at a time, oldest first.
    // `typed` is how much of the newest one shows. Opens with a boot.
    this.log = [];
    this.queue = [];
    this.typed = 0;
    this.seen = null;
    this.say("MU/TH/UR 6000 ONLINE.");
    this.say("INTERFACE 2037 READY FOR INQUIRY.");
    // Types the queue out; idle ticks draw nothing.
    cx.timer.every(28, (cx) => {
      const line = this.log[this.log.length - 1];
      if (line && this.typed < line.text.length) { this.typed += 2; cx.notify(); }
      else if (this.queue.length) { this.log.push(this.queue.shift()); this.log = this.log.slice(-14); this.typed = 0; cx.notify(); }
    });
  }

  say(text, tone) {
    this.queue.push({ text: `${clock()} ${text}`, tone });
  }

  // What changed in the crew since the last render, as console lines.
  watch(crew, sectors) {
    const now = new Map(crew.map((a) => [a.address, a]));
    if (this.seen === null) {
      this.say(`${pad(crew.length)} CREW ON STATION · ${pad(sectors)} SECTORS.`);
    } else {
      for (const a of crew) {
        const before = this.seen.get(a.address);
        if (!before) this.say(`${agentName(a)} REPORTING.`);
        if (a.status !== before?.status && EVENTS[a.status]) this.say(`${agentName(a)} // ${EVENTS[a.status]}`, a.status);
      }
      for (const [address, a] of this.seen)
        if (!now.has(address)) this.say(`${agentName(a)} // SIGNAL LOST.`, "blocked");
    }
    this.seen = new Map(crew.map((a) => [a.address, { status: a.status, program: a.program, app: a.app, tab_index: a.tab_index }]));
  }

  console(t) {
    const last = this.log.length - 1;
    const cursor = () => div().flex_none().w(7).h(12).bg(t.foreground).loop("opacity", { from: 0, to: 1, period: 1060 });
    const typing = last >= 0 && this.typed < this.log[last].text.length;
    return v_flex().id("console").flex_1().min_h(0).px(14).gap(3).justify_end().overflow_hidden().text_size(11)
      .children(this.log.map((line, i) => {
        const text = i === last ? line.text.slice(0, this.typed) : line.text;
        const tone = line.tone ? t[line.tone] : i === last ? t.foreground : t.muted;
        return h_flex().items_end().gap(2).text_color(tone)
          .child(div().min_w(0).child(`> ${text}`))
          .when(i === last && typing, (el) => el.child(cursor()));
      }))
      .when(!typing, (el) => el.child(h_flex().gap(2).items_end().text_color(t.foreground).child(">").child(cursor())));
  }

  render() {
    const t = theme();
    this.watch(agents(), spaces().length);
    const stop = (_e, cx) => cx.stop_propagation();

    const sectorRows = spaces().map((s) => {
      const on = s.active;
      return h_flex().id(`sector-${s.id}`).h(24).mx(6).px(8).gap(8).items_center().text_size(12.5)
        .bg(on ? t.foreground : t.chrome).text_color(on ? t.chrome : t.foreground)
        .hover((st) => on ? st : st.bg(t.hover))
        .on_click(() => run("space.select", { id: s.id }))
        .on_mouse_down("right", (_e, cx) => {
          cx.stop_propagation();
          openOverlay({ mod: "menu", kind: "popup", width: 200, height: 260, props: { tab: "space", target: { id: s.id } } });
        })
        .child(div().flex_none().text_color(on ? t.chrome : t.dim).child(pad(s.index)))
        .child(div().flex_1().min_w(0).truncate().child(s.name.toUpperCase()))
        .when(Boolean(s.machine), (el) => el.child(div().flex_none().text_size(10.5).text_color(on ? t.chrome : t.dim).child(`@${s.machine.toUpperCase()}`)))
        .when(Boolean(s.status) && s.status !== "idle", (el) => el.child(statusMark(t, s.status, on)));
    });

    const crew = agents();
    setAgentOrder(crew.map((a) => a.address));
    const crewRows = crew.map((a) => {
      const on = a.focused;
      const word = WORDS[a.status] ?? "UNKNOWN";
      const tone = on ? t.chrome : a.status === "idle" ? t.dim : t[a.status] ?? t.muted;
      return v_flex().id(`crew-${a.address}`).mx(6).px(8).py(4).gap(1)
        .bg(on ? t.foreground : t.chrome).text_color(on ? t.chrome : t.foreground)
        .hover((st) => on ? st : st.bg(t.hover))
        .on_click(() => run("agent.focus", { terminal: a.address }))
        .child(h_flex().gap(8).items_center().text_size(12.5)
          .child(div().flex_none().child(">"))
          .child(div().flex_1().min_w(0).truncate().child((a.program?.name ?? a.app ?? "AGENT").toUpperCase()))
          .when(a.status === "working", (el) => el.child(statusMark(t, "working", on))))
        .child(h_flex().gap(8).text_size(10.5).pl(16)
          .child(div().flex_1().min_w(0).truncate().text_color(on ? t.chrome : t.muted)
            .child(`${a.space_name.toUpperCase()} / CH.${pad(a.tab_index)}`))
          .child(div().flex_none().text_color(tone)
            .when(a.status === "blocked" && !on, (el) => el.loop("opacity", { from: 0.35, to: 1, period: 900 }))
            .child(word)));
    });

    const sysButton = (id, label, action) => div().id(id).px(6).h(22).flex().items_center()
      .text_size(11.5).text_color(t.foreground).hover((s) => s.bg(t.foreground).text_color(t.chrome))
      .on_click(action).child(`[ ${label} ]`);
    const names = layouts();
    const current = shared("layout");
    const nextLayout = names[(names.indexOf(current) + 1) % Math.max(1, names.length)];

    return v_flex().id("root").size_full().bg(t.chrome).text_color(t.foreground).px(10).pt(4).gap(4)
      .child(frame(t, "SECTORS",
        v_flex().id("sectors").gap(2).max_h(220).overflow_y_scrollbar().children(sectorRows),
        div().id("sector-new").h(16).px(6).flex().items_center().text_size(11).text_color(t.foreground)
          .hover((s) => s.bg(t.foreground).text_color(t.chrome))
          .on_mouse_down("left", stop).on_click(() => run("space.new")).child("[ + ]")))
      .child(frame(t, "CREW",
        crewRows.length
          ? v_flex().id("crew").gap(2).overflow_y_scrollbar().children(crewRows)
          : div().px(14).py(4).text_size(11.5).text_color(t.dim).child("> NO CREW ACTIVE.")))
      .child(this.consoleFrame(t))
      .child(frame(t, "SYSTEM",
        h_flex().flex_wrap().px(6).gap(2)
          .child(sysButton("sys-settings", "SETTINGS", () => run("app.settings")))
          .child(sysButton("sys-palette", "COMMANDS", () => run("app.palette")))
          .when(Boolean(nextLayout) && nextLayout !== current, (el) =>
            el.child(sysButton("sys-layout", "LAYOUT", () => run("layout.switch", { name: nextLayout }))))))
      .child(this.terrain(t));
  }

  // The console takes the height that's left between CREW and SYSTEM.
  consoleFrame(t) {
    return frame(t, "MU/TH/UR", this.console(t), null, true);
  }

  // Rails to a vanishing point at the top edge and cross lines in
  // perspective (depth d at height H / d), each swaying between its place
  // and the next one's: the ground drifting under a hovering ship.
  terrain(t) {
    const W = 280, H = 170;
    const lines = [];
    for (let k = 1; k <= 18; k++) {
      const from = H / (k + 1), to = H / k;
      lines.push(div().absolute().left(0).w(W).h(1).bg(t.dim).opacity(Math.min(1, from / (H * 0.3)) * 0.8)
        .top(from).loop("top", { from, to, period: 5000, easing: "linear" }));
    }
    return div().relative().w(W).h(H).flex_none().overflow_hidden().mb(4)
      .child(div().absolute().left(0).top(0).w(W).h(H).opacity(0.55)
        .child(svg("mods/muthur-roster/terrain.svg").w(W).h(H).text_color(t.dim)))
      .children(lines)
      .child(div().absolute().left(0).top(0).w(W).h(1).bg(t.foreground).opacity(0.6));
  }
}
