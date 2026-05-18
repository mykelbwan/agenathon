// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {AuctionClock} from "../src/AuctionClock.sol";

contract AuctionClockScript is Script {
    AuctionClock public clock;

    function run() public {
        address dutchAuction = vm.envAddress("DUTCH_AUCTION_ADDRESS");
        uint64 gasLimit = uint64(vm.envUint("AUCTION_CLOCK_GAS_LIMIT"));

        vm.startBroadcast();
        clock = new AuctionClock{value: 32 ether}(dutchAuction, gasLimit);
        vm.stopBroadcast();
    }
}
