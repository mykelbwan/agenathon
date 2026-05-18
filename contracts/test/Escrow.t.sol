// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";

contract EscrowTest is Test {
    event DataProviderSet(address indexed dataProvider);
    event PaymentLocked(uint256 indexed auctionId, address buyer, address provider, uint256 amount);
    event PaymentReleased(uint256 indexed auctionId, address provider, uint256 amount);
    event PaymentRefunded(uint256 indexed auctionId, address buyer, uint256 amount);

    Escrow public escrow;
    address public owner = address(0xA11CE);
    address public dataProvider = address(0xDADA);
    address public buyer = address(0xB0B);
    address public provider = address(0xF00D);

    function setUp() public {
        escrow = new Escrow(owner);
    }

    function test_setDataProviderOnlyOwnerAndOnlyOnce() public {
        vm.prank(buyer);
        vm.expectRevert(Escrow.OnlyOwner.selector);
        escrow.setDataProvider(dataProvider);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit DataProviderSet(dataProvider);
        escrow.setDataProvider(dataProvider);

        assertEq(escrow.dataProvider(), dataProvider);

        vm.prank(owner);
        vm.expectRevert(Escrow.DataProviderAlreadySet.selector);
        escrow.setDataProvider(address(0xDAD1));
    }

    function test_setDataProviderRejectsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Escrow.ZeroAddress.selector);
        escrow.setDataProvider(address(0));
    }

    function test_lockPaymentStoresRecordAndBalance() public {
        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, false, false, true);
        emit PaymentLocked(1, buyer, provider, 3 ether);
        escrow.lockPayment{value: 3 ether}(1, buyer, provider, 15);

        (
            address recordBuyer,
            address recordProvider,
            uint256 amount,
            uint256 lockedAtBlock,
            uint256 timeoutBlocks,
            Escrow.EscrowStatus status
        ) = escrow.records(1);

        assertEq(recordBuyer, buyer);
        assertEq(recordProvider, provider);
        assertEq(amount, 3 ether);
        assertEq(lockedAtBlock, block.number);
        assertEq(timeoutBlocks, 15);
        assertEq(uint256(status), uint256(Escrow.EscrowStatus.Locked));
        assertEq(address(escrow).balance, 3 ether);
    }

    function test_lockPaymentRevertsForDuplicateOrInvalidInput() public {
        escrow.lockPayment{value: 1 ether}(1, buyer, provider, 15);

        vm.expectRevert(Escrow.RecordAlreadyExists.selector);
        escrow.lockPayment{value: 1 ether}(1, buyer, provider, 15);

        vm.expectRevert(Escrow.NoPayment.selector);
        escrow.lockPayment(2, buyer, provider, 15);

        vm.expectRevert(Escrow.ZeroAddress.selector);
        escrow.lockPayment{value: 1 ether}(3, address(0), provider, 15);

        vm.expectRevert(Escrow.ZeroAddress.selector);
        escrow.lockPayment{value: 1 ether}(4, buyer, address(0), 15);

        vm.expectRevert(Escrow.InvalidTimeout.selector);
        escrow.lockPayment{value: 1 ether}(5, buyer, provider, 0);
    }

    function test_releaseTransfersFundsToProvider() public {
        vm.prank(owner);
        escrow.setDataProvider(dataProvider);
        escrow.lockPayment{value: 4 ether}(1, buyer, provider, 15);

        uint256 providerBalanceBefore = provider.balance;

        vm.prank(dataProvider);
        vm.expectEmit(true, false, false, true);
        emit PaymentReleased(1, provider, 4 ether);
        escrow.release(1);

        (, , , , , Escrow.EscrowStatus status) = escrow.records(1);
        assertEq(uint256(status), uint256(Escrow.EscrowStatus.Released));
        assertEq(provider.balance, providerBalanceBefore + 4 ether);
        assertEq(address(escrow).balance, 0);
    }

    function test_releaseRevertsWhenUnauthorizedOrUnavailable() public {
        escrow.lockPayment{value: 2 ether}(1, buyer, provider, 15);

        vm.prank(buyer);
        vm.expectRevert(Escrow.OnlyDataProvider.selector);
        escrow.release(1);

        vm.prank(owner);
        escrow.setDataProvider(dataProvider);

        vm.prank(dataProvider);
        escrow.release(1);

        vm.prank(dataProvider);
        vm.expectRevert(Escrow.RecordNotLocked.selector);
        escrow.release(1);
    }

    function test_claimRefundTransfersFundsBackToBuyerAfterTimeout() public {
        escrow.lockPayment{value: 5 ether}(1, buyer, provider, 3);

        vm.roll(block.number + 4);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        vm.expectEmit(true, false, false, true);
        emit PaymentRefunded(1, buyer, 5 ether);
        escrow.claimRefund(1);

        (, , , , , Escrow.EscrowStatus status) = escrow.records(1);
        assertEq(uint256(status), uint256(Escrow.EscrowStatus.Refunded));
        assertEq(buyer.balance, buyerBalanceBefore + 5 ether);
        assertEq(address(escrow).balance, 0);
    }

    function test_claimRefundRevertsWhenUnauthorizedOrEarly() public {
        escrow.lockPayment{value: 5 ether}(1, buyer, provider, 3);

        vm.prank(provider);
        vm.expectRevert(Escrow.OnlyBuyer.selector);
        escrow.claimRefund(1);

        vm.prank(buyer);
        vm.expectRevert(Escrow.TimeoutNotReached.selector);
        escrow.claimRefund(1);
    }
}
