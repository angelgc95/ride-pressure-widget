import type { ProviderAdapter } from "@/lib/server/providers/base";
import type { ProviderSnapshot } from "@/lib/types";

export class BoltAdapter implements ProviderAdapter {
  readonly provider = "bolt" as const;

  async observe({
    observedAt,
  }: Parameters<ProviderAdapter["observe"]>[0]): Promise<ProviderSnapshot> {
    return {
      provider: this.provider,
      supportLevel: "unsupported",
      availabilityState: "unsupported",
      tone: "neutral",
      statusLabel: "Unsupported",
      observedAt,
      sourceBlend: "unavailable",
      freshnessHours: null,
      note: "No trustworthy public Bolt pricing or availability endpoint is configured in this build.",
      signals: {},
    };
  }
}
