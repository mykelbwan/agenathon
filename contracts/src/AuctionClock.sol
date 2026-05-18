// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {SomniaEventHandler} from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";
import {ISomniaReactivityPrecompile} from "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaReactivityPrecompile.sol";
import {SomniaExtensions} from "@somnia-chain/reactivity-contracts/contracts/interfaces/SomniaExtensions.sol";
import {IDutchAuction} from "../interface/IDutchAuction.sol";
import {IAuctionClock} from "../interface/IAuctionClock.sol";

contract AuctionClock is SomniaEventHandler, IAuctionClock {
    address public immutable DUTCH_AUCTION;
    uint256 public subscriptionId;

    constructor(address dutchAuction_, uint64 gasLimit) payable {
        DUTCH_AUCTION = dutchAuction_;

        SomniaExtensions.SubscriptionFilter memory filter = SomniaExtensions
            .SubscriptionFilter({
                eventTopics: [
                    ISomniaReactivityPrecompile.BlockTick.selector,
                    bytes32(0),
                    bytes32(0),
                    bytes32(0)
                ],
                origin: address(0),
                emitter: SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS
            });

        SomniaExtensions.SubscriptionOptions memory options = SomniaExtensions
            .SubscriptionOptions({
                priorityFeePerGas: 1,
                maxFeePerGas: 0,
                gasLimit: gasLimit
            });

        subscriptionId = SomniaExtensions.subscribe(
            address(this),
            filter,
            options
        );
    }

    function dutchAuction() external view override returns (address) {}

    function _onEvent(
        address,
        bytes32[] calldata,
        bytes calldata
    ) internal override {
        uint256[] memory activeAuctions = IDutchAuction(DUTCH_AUCTION)
            .getActiveAuctions();

        for (uint256 i = 0; i < activeAuctions.length; i++) {
            try
                IDutchAuction(DUTCH_AUCTION).dropPrice(activeAuctions[i])
            {} catch {}
        }
    }

    receive() external payable {}
}
