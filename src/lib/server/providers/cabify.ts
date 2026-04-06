import type { ProviderAdapter } from "@/lib/server/providers/base";
import type { ProviderSnapshot } from "@/lib/types";

export class CabifyAdapter implements ProviderAdapter {
  readonly provider = "cabify" as const;

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
      note: "Cabify is shown in the UI, but this version does not ship a public, verified Cabify price adapter.",
      signals: {},
    };
  }
}
