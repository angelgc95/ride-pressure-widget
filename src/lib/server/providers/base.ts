import type { CitySelection, ProviderSnapshot } from "@/lib/types";

export interface ObserveProviderArgs {
  city: CitySelection;
  observedAt: string;
}

export interface ProviderAdapter {
  readonly provider: ProviderSnapshot["provider"];
  observe(args: ObserveProviderArgs): Promise<ProviderSnapshot>;
}
