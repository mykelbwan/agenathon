// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Escrow} from "../src/Escrow.sol";
import {Script} from "forge-std/Script.sol";

contract EscrowScript is Script {
    Escrow public escrow;

    function run() public {
        address owner = vm.envAddress("ESCROW_OWNER");

        vm.startBroadcast();
        escrow = new Escrow(owner);
        vm.stopBroadcast();
    }
}
