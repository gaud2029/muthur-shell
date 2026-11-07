// MU/TH/UR 6000 layout: the tab strip, as channels. The shown one is
// inverted; click to switch, double-click to rename, right-click for the
// tab menu, scroll to step through. [ + ] opens Herdr's new-tab menu and
// [ FILES ] / [ DIFF ] toggle the side panel.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, panes, run, openOverlay, theme, layout } from "herdr";

const pad = (n) => String(n).padStart(2, "0");
// A scanner: a block sweeping back and forth in a frame, natively (block
// characters like ░▒▓ fall back to another font in the panels).
function scanner(color, w = 34) {
  return div().relative().flex_none().w(w).h(8).border(1).border_color(color)
    .child(div().absolute().top(1).left(1).h(4).w(8).bg(color).loop("left", { from: 1, to: w - 11, period: 1100 }));
}

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class Tabs extends View {
  render() {
    const t = theme();
    const space = spaces().find((s) => s.active);
    const stop = (_e, cx) => cx.stop_propagation();

    const channel = (c) => {
      const on = c.active;
      const program = panes().find((p) => p.tab === c.id && p.program?.agent)?.program
        ?? panes().find((p) => p.tab === c.id)?.program;
      const name = (c.named ? c.name : program?.name ?? "TERMINAL").toUpperCase();
      const ink = on ? t.chrome : t.foreground;
      return h_flex().id(`ch-${c.id}`).h(24).px(10).gap(8).flex_none().items_center().text_size(12)
        .bg(on ? t.foreground : t.chrome).text_color(on ? t.chrome : t.muted)
        .border(1).border_color(on ? t.foreground : t.dim)
        .hover((s) => on ? s : s.bg(t.hover).text_color(t.foreground))
        .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); if (e.click_count === 2) run("tab.rename", { id: c.id }); })
        .on_click(() => run("tab.select", { id: c.id }))
        .on_mouse_down("right", (_e, cx) => {
          cx.stop_propagation();
          openOverlay({ mod: "menu", kind: "popup", width: 200, props: { tab: "tab", target: { id: c.id, space: space.id } } });
        })
        .child(div().text_color(on ? t.chrome : t.dim).child(`CH.${pad(c.index)}`))
        .child(div().max_w(200).truncate().text_color(ink).child(c.zoomed ? `${name} [Z]` : name))
        .when(c.status === "working", (el) => el.child(scanner(on ? t.chrome : t.working)))
        .when(c.status === "blocked", (el) => el.child(div().text_color(on ? t.chrome : t.blocked).loop("opacity", { from: 0.3, to: 1, period: 900 }).child("!!")))
        .when(c.status === "done", (el) => el.child(div().text_color(on ? t.chrome : t.done).child("■")))
        .when(on, (el) => el.child(div().id(`ch-close-${c.id}`).text_color(t.chrome).hover((s) => s.text_color(t.blocked))
          .on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: c.id }); }).child("×")));
    };

    const root = layout(), panel = find(root, "panel"), body = find(root, "panel-body");
    const toggle = (id, label) => {
      const on = panel && !panel.hidden && body?.active === id;
      return div().id(`panel-${id}`).h(24).px(8).flex().items_center().flex_none().text_size(11.5)
        .bg(on ? t.foreground : t.chrome).text_color(on ? t.chrome : t.foreground)
        .hover((s) => on ? s : s.bg(t.hover))
        .on_mouse_down("left", stop)
        .on_click(() => {
          if (on) run("layout.hide", { id: "panel" });
          else { run("layout.select", { stack: "panel-body", child: id }); run("layout.show", { id: "panel" }); }
        })
        .child(`[ ${label} ]`);
    };

    return h_flex().size_full().min_w(0).px(10).gap(6).items_center().bg(t.chrome)
      .border_b(1).border_color(t.dim)
      .on_scroll_wheel((e) => { if (Math.abs(e.delta.y) >= 1) run(e.delta.y > 0 ? "tab.prev" : "tab.next"); })
      .child(div().flex_none().text_size(11).text_color(t.dim).child("CHANNELS //"))
      .child(h_flex().id("ch-scroll").flex_1().min_w(0).h_full().items_center().gap(6).overflow_x_scrollbar()
        .children((space?.tabs ?? []).map(channel))
        .child(div().id("ch-new").h(24).px(8).flex().items_center().flex_none().text_size(12).text_color(t.foreground)
          .hover((s) => s.bg(t.foreground).text_color(t.chrome)).on_mouse_down("left", stop)
          .on_click(() => openOverlay({ mod: "new-menu", kind: "popup", width: 250, height: 512 }))
          .child("[ + ]")))
      .child(toggle("files", "FILES"))
      .child(toggle("changes", "DIFF"));
  }
}
