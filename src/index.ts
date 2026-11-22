import { requireNativeModule } from 'expo-modules-core';

export type ContentState = {
  title: string;
  subtitle?: string;
  progress?: number; // 0..1
  endDate?: number; // epoch seconds, drives the countdown
  status?: string;
  values?: Record<string, string>;
};

export type TokenEvent = { kind: 'pushToStart' | 'activity'; token: string };

type Native = {
  configure(key: string, baseUrl: string | null): void;
  identify(userId: string | null): void;
  start(state: ContentState, name: string, staleDateMs: number | null): Promise<string>;
  schedule(state: ContentState, startAtMs: number, name: string): Promise<string>;
  update(id: string, state: ContentState): Promise<void>;
  end(id: string, state: ContentState | null): Promise<void>;
  addListener(event: 'onToken', cb: (e: TokenEvent) => void): { remove(): void };
};

// Loaded lazily so importing on Android / web does not throw until a call is made.
let mod: Native | undefined;
const native = () => (mod ??= requireNativeModule<Native>('LiveActivity'));

const DEFAULT_NAME = 'default';

export function configure(opts: { publishableKey: string; baseUrl?: string }): void {
  native().configure(opts.publishableKey, opts.baseUrl ?? null);
}

export function identify(userId: string | null): void {
  native().identify(userId);
}

/** Starts an activity on this device now. Resolves with an id usable in update() / end(). */
export function start(contentState: ContentState, opts: { name?: string; staleDate?: Date } = {}): Promise<string> {
  return native().start(contentState, opts.name ?? DEFAULT_NAME, opts.staleDate?.getTime() ?? null);
}

/** Schedules a start: iOS 26 local scheduled start, otherwise server push-to-start. Resolves with the server activity id. */
export function schedule(contentState: ContentState, startAt: Date, opts: { name?: string } = {}): Promise<string> {
  return native().schedule(contentState, startAt.getTime(), opts.name ?? DEFAULT_NAME);
}

export function update(id: string, contentState: ContentState): Promise<void> {
  return native().update(id, contentState);
}

export function end(id: string, contentState?: ContentState): Promise<void> {
  return native().end(id, contentState ?? null);
}

export function addTokenListener(cb: (e: TokenEvent) => void): { remove(): void } {
  return native().addListener('onToken', cb);
}
