import type { ProviderAdapter } from "@/lib/server/providers/base";
import type { ProviderSnapshot } from "@/lib/types";

export class FreeNowAdapter implements ProviderAdapter {
  readonly provider = "freenow" as const;

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
      note: "FREE NOW currently has no verified anonymous price surface connected to this local build.",
      signals: {},
    };
  }
}
