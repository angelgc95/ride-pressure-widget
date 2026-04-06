import { logger } from "@/lib/server/logger";

export class HttpError extends Error {
  readonly status: number;
  readonly url: string;

  constructor(message: string, status: number, url: string) {
    super(message);
    this.name = "HttpError";
    this.status = status;
    this.url = url;
  }
}

interface FetchJsonOptions extends RequestInit {
  retries?: number;
  timeoutMs?: number;
  name?: string;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchJson<T>(
  url: string,
  options: FetchJsonOptions = {},
): Promise<T> {
  const {
    retries = 2,
    timeoutMs = 9000,
    headers,
    name = url,
    ...init
  } = options;

  let lastError: unknown;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMs);

      const response = await fetch(url, {
        ...init,
        cache: "no-store",
        headers: {
          "content-type": "application/json",
          ...headers,
        },
        signal: controller.signal,
      });

      clearTimeout(timeout);

      if (!response.ok) {
        throw new HttpError(
          `${name} failed with status ${response.status}`,
          response.status,
          url,
        );
      }

      return (await response.json()) as T;
    } catch (error) {
      lastError = error;
      if (attempt === retries) {
        break;
      }

      logger.warn("Retrying upstream request", {
        name,
        attempt: attempt + 1,
        error: error instanceof Error ? error.message : String(error),
      });

      await sleep(250 * (attempt + 1));
    }
  }

  throw lastError;
}
