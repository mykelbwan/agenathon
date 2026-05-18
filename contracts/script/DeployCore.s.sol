// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Escrow} from "../src/Escrow.sol";
import {AuctionClock} from "../src/AuctionClock.sol";
import {DutchAuction} from "../src/DutchAuction.sol";
import {DataProvider} from "../src/DataProvider.sol";

contract DeployCoreScript is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        address platform = vm.envAddress("SOMNIA_AGENT_PLATFORM");
        uint256 jsonApiAgentId = vm.envUint("JSON_API_AGENT_ID");
        uint64 auctionClockGasLimit = uint64(vm.envUint("AUCTION_CLOCK_GAS_LIMIT"));

        uint256 currentNonce = vm.getNonce(deployer);
        address predictedDutchAuction = vm.computeCreateAddress(deployer, currentNonce + 2);

        vm.startBroadcast(privateKey);

        Escrow escrow = new Escrow(deployer);
        AuctionClock auctionClock = new AuctionClock{value: 32 ether}(predictedDutchAuction, auctionClockGasLimit);
        DutchAuction dutchAuction = new DutchAuction(address(auctionClock), address(escrow));
        DataProvider dataProvider = new DataProvider(platform, jsonApiAgentId, address(escrow), address(dutchAuction));
        escrow.setDataProvider(address(dataProvider));

        vm.stopBroadcast();

        console2.log("Escrow:", address(escrow));
        console2.log("AuctionClock:", address(auctionClock));
        console2.log("DutchAuction:", address(dutchAuction));
        console2.log("DataProvider:", address(dataProvider));
    }
}
