// The Koyomi hook for a LiveSocket, and `mountKoyomi` for a page without
// LiveView. The hook makes a Picker of its element, gives it the server's
// later renders (`updated`), and passes the events of Koyomi.Live
// (koyomi:set, koyomi:days, koyomi:refresh, koyomi:open, koyomi:close,
// koyomi:focus) to the picker they name.

import { Picker, type Transport } from "./picker";

interface HookContext {
  el: HTMLElement;
  pushEvent(event: string, payload: object, onReply?: (reply: Record<string, unknown>, ref: number) => void): void;
  pushEventTo(target: string | HTMLElement, event: string, payload: object, onReply?: (reply: Record<string, unknown>, ref: number) => void): void;
  handleEvent(event: string, callback: (payload: Record<string, unknown>) => void): void;
}

interface KoyomiHook extends HookContext {
  picker?: Picker;
}

const SERVER_EVENTS = ["koyomi:set", "koyomi:days", "koyomi:refresh", "koyomi:open", "koyomi:close", "koyomi:focus"];

function onServerEvent(picker: Picker, event: string, payload: Record<string, unknown>): void {
  if (payload.id !== picker.id) return;
  switch (event) {
    case "koyomi:set":
      picker.set((payload.value ?? null) as Parameters<Picker["set"]>[0]);
      break;
    case "koyomi:days":
      picker.receiveDays(payload);
      break;
    case "koyomi:refresh":
      picker.refreshDays();
      break;
    case "koyomi:open":
      picker.open();
      break;
    case "koyomi:close":
      picker.close();
      break;
    case "koyomi:focus":
      picker.focus();
      break;
  }
}

export const Koyomi = {
  mounted(this: KoyomiHook) {
    const hook = this;
    const target = hook.el.getAttribute("phx-target");
    const transport: Transport = {
      push(event, payload, onReply) {
        const reply = onReply ? (response: Record<string, unknown>) => onReply(response) : undefined;
        if (target) hook.pushEventTo(target, event, payload, reply);
        else hook.pushEvent(event, payload, reply);
      },
    };
    hook.picker = new Picker(hook.el, transport);
    for (const event of SERVER_EVENTS) {
      hook.handleEvent(event, (payload) => {
        if (hook.picker) onServerEvent(hook.picker, event, payload);
      });
    }
  },

  updated(this: KoyomiHook) {
    this.picker?.update();
  },

  destroyed(this: KoyomiHook) {
    this.picker?.destroy();
    this.picker = undefined;
  },
};

const mounted = new WeakMap<HTMLElement, Picker>();

/**
 * Mounts the pickers under `root` on a page without a LiveSocket (a
 * controller's template): the same pickers, with no day content and no
 * server events. Returns them; a picker already mounted is skipped.
 */
export function mountKoyomi(root: ParentNode = document): Picker[] {
  const pickers: Picker[] = [];
  for (const element of root.querySelectorAll<HTMLElement>('[phx-hook="Koyomi"]')) {
    if (mounted.has(element)) continue;
    const picker = new Picker(element, null);
    mounted.set(element, picker);
    pickers.push(picker);
  }
  return pickers;
}
