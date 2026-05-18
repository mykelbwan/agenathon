// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {DataProvider} from "../src/DataProvider.sol";
import {Script} from "forge-std/Script.sol";

contract DataProviderScript is Script {
    DataProvider public dataProvider;

    function run() public {
        address platform = vm.envAddress("SOMNIA_AGENT_PLATFORM");
        uint256 jsonApiAgentId = vm.envUint("JSON_API_AGENT_ID");
        address escrow = vm.envAddress("ESCROW_ADDRESS");
        address dutchAuction = vm.envAddress("DUTCH_AUCTION_ADDRESS");

        vm.startBroadcast();
        dataProvider = new DataProvider(platform, jsonApiAgentId, escrow, dutchAuction);
        vm.stopBroadcast();
    }
}
