import HotkeysConfig from "@/core/hotkeys/HotkeysConfig";

export type HotkeyListener = () => void;

export type HotkeyIndex = Record<string, string[]>;
export type ListenerIndex = Record<string, HotkeyListener[]>;

export type HotkeyAction = keyof typeof HotkeysConfig.Keys;

export type HotkeyBindingsList = Record<string, HotkeyAction>;
