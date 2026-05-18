// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ConsumerHandler} from "../src/ConsumerHandler.sol";
import {Script} from "forge-std/Script.sol";

contract ConsumerHandlerScript is Script {
    ConsumerHandler public consumerHandler;

    function run() public {
        address dutchAuction = vm.envAddress("DUTCH_AUCTION_ADDRESS");
        address dataProvider = vm.envAddress("DATA_PROVIDER_ADDRESS");
        uint256 snapThreshold = vm.envUint("CONSUMER_SNAP_THRESHOLD");
        string memory targetDataType = vm.envString("CONSUMER_TARGET_DATA_TYPE");
        uint64 gasLimit = uint64(vm.envUint("CONSUMER_HANDLER_GAS_LIMIT"));
        uint256 deployValue = vm.envUint("CONSUMER_HANDLER_DEPLOY_VALUE");

        vm.startBroadcast();
        consumerHandler =
            new ConsumerHandler{value: deployValue}(dutchAuction, dataProvider, snapThreshold, targetDataType, gasLimit);
        vm.stopBroadcast();
    }
}
