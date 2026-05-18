// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {DutchAuction} from "../src/DutchAuction.sol";

contract DutchAuctionScript is Script {
    DutchAuction public auction;

    function run() public {
        address clock = vm.envAddress("AUCTION_CLOCK_ADDRESS");
        address escrow = vm.envAddress("ESCROW_ADDRESS");

        vm.startBroadcast();
        auction = new DutchAuction(clock, escrow);
        vm.stopBroadcast();
    }
}
