import "expo-sqlite/localStorage/install";

type Listener = () => void;
const listeners = new Map<string, Set<Listener>>();

export const storage = {
  get<T>(key: string, defaultValue: T): T {
    const value = localStorage.getItem(key);
    return value ? JSON.parse(value) : defaultValue;
  },

  set<T>(key: string, value: T): void {
    localStorage.setItem(key, JSON.stringify(value));
    listeners.get(key)?.forEach((fn) => {
      fn();
    });
  },

  subscribe(key: string, listener: Listener): () => void {
    if (!listeners.has(key)) listeners.set(key, new Set());
    const keyListeners = listeners.get(key);
    if (keyListeners) {
      keyListeners.add(listener);
    }
    return () => listeners.get(key)?.delete(listener);
  },
};
