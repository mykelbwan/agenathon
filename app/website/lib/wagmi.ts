import { createConfig, http, injected } from "wagmi";

import { somniaTestnet } from "@/lib/chain";

export const wagmiConfig = createConfig({
  chains: [somniaTestnet],
  connectors: [injected()],
  multiInjectedProviderDiscovery: true,
  transports: {
    [somniaTestnet.id]: http(somniaTestnet.rpcUrls.default.http[0]),
  },
});
