// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IConsumerHandler {
    event Snapped(uint256 indexed auctionId, uint256 price);
    event DataReceived(uint256 indexed auctionId, uint256 price);

    function withdraw() external;
}
