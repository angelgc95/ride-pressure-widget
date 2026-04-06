const scope = "ride-pressure";

function formatMessage(level: string, message: string, meta?: unknown) {
  const prefix = `[${scope}] ${level.toUpperCase()}`;
  if (meta === undefined) {
    return [prefix, message] as const;
  }

  return [prefix, message, meta] as const;
}

export const logger = {
  info(message: string, meta?: unknown) {
    console.info(...formatMessage("info", message, meta));
  },
  warn(message: string, meta?: unknown) {
    console.warn(...formatMessage("warn", message, meta));
  },
  error(message: string, meta?: unknown) {
    console.error(...formatMessage("error", message, meta));
  },
};
