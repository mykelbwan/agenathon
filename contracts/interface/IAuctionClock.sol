// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IAuctionClock {
    function dutchAuction() external view returns (address);

    function subscriptionId() external view returns (uint256);
}
