// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Escrow} from "../src/Escrow.sol";
import {AuctionClock} from "../src/AuctionClock.sol";
import {DutchAuction} from "../src/DutchAuction.sol";
import {DataProvider} from "../src/DataProvider.sol";
import {MockAgentPlatform} from "../src/mocks/MockAgentPlatform.sol";

contract DeployLocalScript is Script {
    uint256 internal constant LOCAL_JSON_API_AGENT_ID = 13174292974160097713;

    function run() public {
        uint256 privateKey = vm.envUint("LOCAL_PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        uint64 auctionClockGasLimit = uint64(vm.envUint("AUCTION_CLOCK_GAS_LIMIT"));

        uint256 currentNonce = vm.getNonce(deployer);
        address predictedDutchAuction = vm.computeCreateAddress(deployer, currentNonce + 3);

        vm.startBroadcast(privateKey);

        MockAgentPlatform platform = new MockAgentPlatform();
        Escrow escrow = new Escrow(deployer);
        AuctionClock auctionClock = new AuctionClock{value: 32 ether}(predictedDutchAuction, auctionClockGasLimit);
        DutchAuction dutchAuction = new DutchAuction(address(auctionClock), address(escrow));
        DataProvider dataProvider =
            new DataProvider(address(platform), LOCAL_JSON_API_AGENT_ID, address(escrow), address(dutchAuction));
        escrow.setDataProvider(address(dataProvider));

        vm.stopBroadcast();

        console2.log("MockAgentPlatform:", address(platform));
        console2.log("Escrow:", address(escrow));
        console2.log("AuctionClock:", address(auctionClock));
        console2.log("DutchAuction:", address(dutchAuction));
        console2.log("DataProvider:", address(dataProvider));
    }
}
