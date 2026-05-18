// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ISomniaReactivityPrecompile} from "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaReactivityPrecompile.sol";

contract MockReactivityPrecompile is ISomniaReactivityPrecompile {
    uint256 public nextSubscriptionId;

    mapping(uint256 => SubscriptionData) internal subscriptions;
    mapping(uint256 => address) internal owners;

    function subscribe(
        SubscriptionData calldata subscriptionData
    ) external returns (uint256 subscriptionId) {
        subscriptionId = nextSubscriptionId;
        if (subscriptionId == 0) {
            subscriptionId = 1;
        }

        nextSubscriptionId = subscriptionId + 1;
        subscriptions[subscriptionId] = subscriptionData;
        owners[subscriptionId] = msg.sender;

        emit SubscriptionCreated(subscriptionId, msg.sender, subscriptionData);
    }

    function unsubscribe(uint256 subscriptionId) external {
        delete subscriptions[subscriptionId];
        delete owners[subscriptionId];
        emit SubscriptionRemoved(subscriptionId, msg.sender);
    }

    function getSubscriptionInfo(
        uint256 subscriptionId
    ) external view returns (SubscriptionData memory subscriptionData, address owner) {
        return (subscriptions[subscriptionId], owners[subscriptionId]);
    }
}
