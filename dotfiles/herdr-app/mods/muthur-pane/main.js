// MU/TH/UR 6000 layout: each pane's header. The focused pane's header is
// inverted, a solid bar over the terminal that has the keyboard; the
// others stay quiet. Shows the channel (the pane's place in its tab),
// what runs there, its folder and the agent's state in words; on hover,
// text buttons split, zoom and close the pane. Props: { pane, terminal }.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { panes, props, run, theme, home } from "herdr";

const pad = (n) => String(n).padStart(2, "0");
// A scanner: a block sweeping back and forth in a frame, natively (block
// characters like ░▒▓ fall back to another font in the panels).
function scanner(color, w = 34) {
  return div().relative().flex_none().w(w).h(8).border(1).border_color(color)
    .child(div().absolute().top(1).left(1).h(4).w(8).bg(color).loop("left", { from: 1, to: w - 11, period: 1100 }));
}
const WORDS = { working: "WORKING", blocked: "AWAITING ORDERS", done: "TASK COMPLETE" };

function folder(cwd) {
  if (!cwd) return "";
  const h = home();
  return cwd === h ? "~" : cwd.startsWith(h + "/") ? "~" + cwd.slice(h.length) : cwd;
}

export default class Pane extends View {
  init() { this.hovered = false; }

  render() {
    const t = theme();
    const all = panes();
    const p = all.find((x) => x.pane === props()?.pane);
    if (!p) return div();
    const on = p.focused;
    const bg = on ? t.foreground : t.background;
    const ink = on ? t.background : t.foreground;
    const quiet = on ? t.background : t.dim;
    const n = all.filter((x) => x.tab === p.tab).findIndex((x) => x.pane === p.pane) + 1;
    const name = (((p.program?.agent || p.program?.shell) && p.program.name) || p.title || p.program?.name || "shell").toUpperCase();
    const st = p.status;
    const button = (id, label, command, args) => div().id(id).px(4).text_color(ink)
      .hover((s) => s.bg(ink).text_color(bg))
      .on_click((_e, cx) => { cx.stop_propagation(); run(command, args); })
      .child(label);

    return h_flex().id(`mh-${p.pane}`).size_full().px(10).gap(10).items_center().text_size(11.5)
      .bg(bg).text_color(ink).border_b(1).border_color(on ? t.foreground : t.dim)
      .on_hover((hovered, cx) => { this.hovered = hovered; cx.notify(); })
      .on_click(() => run("pane.focus", { pane: p.pane }))
      .child(div().flex_none().font_bold().child(on ? "■" : "□"))
      .child(div().flex_none().font_bold().child(`CHANNEL ${pad(n)} // ${name}`))
      .child(div().flex_1().min_w(0).truncate().text_color(quiet).child(folder(p.cwd)))
      .when(st === "working", (el) => el.child(h_flex().flex_none().gap(6).items_center().text_color(on ? ink : t.working)
        .child(WORDS.working).child(scanner(on ? ink : t.working))))
      .when(st === "blocked", (el) => el.child(div().flex_none().px(6).bg(t.blocked).text_color(t.background).font_bold()
        .loop("opacity", { from: 0.45, to: 1, period: 900 }).child(WORDS.blocked)))
      .when(st === "done", (el) => el.child(div().flex_none().text_color(on ? ink : t.done).child(WORDS.done)))
      .when(this.hovered, (el) => el
        .child(button(`mh-r-${p.pane}`, "[│]", "pane.split", { direction: "right", pane: p.pane }))
        .child(button(`mh-d-${p.pane}`, "[─]", "pane.split", { direction: "down", pane: p.pane }))
        .child(button(`mh-z-${p.pane}`, p.zoomed ? "[-]" : "[+]", "pane.zoom", { pane: p.pane }))
        .child(button(`mh-x-${p.pane}`, "[×]", "pane.close", { pane: p.pane })));
  }
}
