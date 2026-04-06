import { BoltAdapter } from "@/lib/server/providers/bolt";
import { CabifyAdapter } from "@/lib/server/providers/cabify";
import { FreeNowAdapter } from "@/lib/server/providers/freenow";
import { UberPublicAdapter } from "@/lib/server/providers/uber-public";

export const providerAdapters = [
  new UberPublicAdapter(),
  new BoltAdapter(),
  new CabifyAdapter(),
  new FreeNowAdapter(),
];
