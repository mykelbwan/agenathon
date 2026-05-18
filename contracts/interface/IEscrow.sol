// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IEscrow {
    function lockPayment(
        uint256 auctionId,
        address buyer,
        address provider,
        uint256 timeoutBlocks
    ) external payable;

    function release(uint256 auctionId) external;
}
