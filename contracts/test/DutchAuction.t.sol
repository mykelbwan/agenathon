// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DutchAuction} from "../src/DutchAuction.sol";
import {IDutchAuction} from "../interface/IDutchAuction.sol";

contract MockEscrow {
    uint256 public lastAuctionId;
    address public lastBuyer;
    address public lastProvider;
    uint256 public lastAmount;
    uint256 public lastTimeoutBlocks;

    function lockPayment(
        uint256 auctionId,
        address buyer,
        address provider,
        uint256 timeoutBlocks
    ) external payable {
        lastAuctionId = auctionId;
        lastBuyer = buyer;
        lastProvider = provider;
        lastAmount = msg.value;
        lastTimeoutBlocks = timeoutBlocks;
    }
}

contract DutchAuctionTest is Test {
    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed provider,
        string dataType,
        uint256 startPrice
    );
    event PriceTick(uint256 indexed auctionId, uint256 newPrice, uint256 blockNumber);
    event AuctionSnapped(uint256 indexed auctionId, address indexed winner, uint256 finalPrice);
    event AuctionExpired(uint256 indexed auctionId);

    DutchAuction public auction;
    MockEscrow public escrow;
    address public clock = address(0xC10C);
    address public provider = address(0xBEEF);
    address public buyer = address(0xCAFE);

    function setUp() public {
        escrow = new MockEscrow();
        auction = new DutchAuction(clock, address(escrow));
    }

    function test_startAuctionEmitsInitialEvents() public {
        vm.startPrank(provider);
        vm.expectEmit(true, true, false, true);
        emit AuctionStarted(1, provider, "ETH/USD", 10 ether);
        vm.expectEmit(true, false, false, true);
        emit PriceTick(1, 10 ether, block.number);

        auction.startAuction(
            "ETH/USD",
            "https://api.example/eth",
            "ethereum.usd",
            8,
            10 ether,
            2 ether,
            1 ether,
            15
        );
        vm.stopPrank();
    }

    function test_startAuctionStoresAuctionState() public {
        uint256 auctionId = _startDefaultAuction();

        assertEq(auctionId, 1);

        IDutchAuction.Auction memory created = auction.getAuction(auctionId);
        assertEq(created.id, 1);
        assertEq(created.provider, provider);
        assertEq(created.dataType, "ETH/USD");
        assertEq(created.apiUrl, "https://api.example/eth");
        assertEq(created.jsonSelector, "ethereum.usd");
        assertEq(created.decimals, 8);
        assertEq(created.startPrice, 10 ether);
        assertEq(created.floorPrice, 2 ether);
        assertEq(created.currentPrice, 10 ether);
        assertEq(created.priceStep, 1 ether);
        assertEq(created.startBlock, block.number);
        assertEq(created.timeoutBlocks, 15);
        assertEq(uint256(created.status), uint256(IDutchAuction.AuctionStatus.Active));
        assertEq(created.winner, address(0));
        assertEq(created.escrowRef, 0);
    }

    function test_startAuctionAddsAuctionToActiveSet() public {
        uint256 auctionId = _startDefaultAuction();
        uint256[] memory activeAuctions = auction.getActiveAuctions();
        assertEq(activeAuctions.length, 1);
        assertEq(activeAuctions[0], auctionId);
    }

    function test_startAuctionRevertsOnInvalidParameters() public {
        vm.startPrank(provider);

        vm.expectRevert(DutchAuction.EmptyDataType.selector);
        auction.startAuction("", "https://api.example/eth", "ethereum.usd", 8, 10 ether, 2 ether, 1 ether, 15);

        vm.expectRevert(DutchAuction.EmptyApiUrl.selector);
        auction.startAuction("ETH/USD", "", "ethereum.usd", 8, 10 ether, 2 ether, 1 ether, 15);

        vm.expectRevert(DutchAuction.EmptyJsonSelector.selector);
        auction.startAuction("ETH/USD", "https://api.example/eth", "", 8, 10 ether, 2 ether, 1 ether, 15);

        vm.expectRevert(DutchAuction.InvalidPriceRange.selector);
        auction.startAuction(
            "ETH/USD", "https://api.example/eth", "ethereum.usd", 8, 1 ether, 2 ether, 1 ether, 15
        );

        vm.expectRevert(DutchAuction.InvalidPriceStep.selector);
        auction.startAuction(
            "ETH/USD", "https://api.example/eth", "ethereum.usd", 8, 10 ether, 2 ether, 0, 15
        );

        vm.expectRevert(DutchAuction.InvalidTimeout.selector);
        auction.startAuction(
            "ETH/USD", "https://api.example/eth", "ethereum.usd", 8, 10 ether, 2 ether, 1 ether, 0
        );

        vm.stopPrank();
    }

    function test_dropPriceOnlyClockAndClampsToFloor() public {
        uint256 auctionId = _startDefaultAuction();

        vm.prank(address(0x1234));
        vm.expectRevert(DutchAuction.OnlyClock.selector);
        auction.dropPrice(auctionId);

        vm.prank(clock);
        vm.expectEmit(true, false, false, true);
        emit PriceTick(auctionId, 9 ether, block.number);
        auction.dropPrice(auctionId);

        assertEq(auction.getAuction(auctionId).currentPrice, 9 ether);

        for (uint256 i = 0; i < 10; i++) {
            vm.roll(block.number + 1);
            vm.prank(clock);
            auction.dropPrice(auctionId);
        }

        assertEq(auction.getAuction(auctionId).currentPrice, 2 ether);
    }

    function test_dropPriceExpiresAuctionAfterTimeout() public {
        uint256 auctionId = _startDefaultAuction();
        IDutchAuction.Auction memory started = auction.getAuction(auctionId);

        vm.roll(started.startBlock + started.timeoutBlocks + 1);
        vm.prank(clock);
        vm.expectEmit(true, false, false, false);
        emit AuctionExpired(auctionId);
        auction.dropPrice(auctionId);

        IDutchAuction.Auction memory ended = auction.getAuction(auctionId);
        assertEq(uint256(ended.status), uint256(IDutchAuction.AuctionStatus.Expired));
        assertEq(auction.getActiveAuctions().length, 0);
    }

    function test_snapLocksEscrowAndRefundsExcess() public {
        uint256 auctionId = _startDefaultAuction();
        vm.deal(buyer, 20 ether);

        vm.prank(clock);
        auction.dropPrice(auctionId);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        vm.expectEmit(true, true, false, true);
        emit AuctionSnapped(auctionId, buyer, 9 ether);
        auction.snap{value: 11 ether}(auctionId);

        IDutchAuction.Auction memory snapped = auction.getAuction(auctionId);
        assertEq(uint256(snapped.status), uint256(IDutchAuction.AuctionStatus.Snapped));
        assertEq(snapped.winner, buyer);
        assertEq(snapped.escrowRef, auctionId);

        assertEq(escrow.lastAuctionId(), auctionId);
        assertEq(escrow.lastBuyer(), buyer);
        assertEq(escrow.lastProvider(), provider);
        assertEq(escrow.lastAmount(), 9 ether);
        assertEq(escrow.lastTimeoutBlocks(), 15);

        assertEq(buyer.balance, buyerBalanceBefore - 9 ether);
        assertEq(auction.getActiveAuctions().length, 0);
    }

    function test_snapRevertsForUnderpaymentAndInactiveAuction() public {
        uint256 auctionId = _startDefaultAuction();
        vm.deal(buyer, 20 ether);

        vm.prank(buyer);
        vm.expectRevert(DutchAuction.InsufficientPayment.selector);
        auction.snap{value: 5 ether}(auctionId);

        vm.prank(buyer);
        auction.snap{value: 10 ether}(auctionId);

        vm.deal(address(0xABCD), 20 ether);
        vm.prank(address(0xABCD));
        vm.expectRevert(DutchAuction.AuctionNotActive.selector);
        auction.snap{value: 10 ether}(auctionId);
    }

    function _startDefaultAuction() internal returns (uint256 auctionId) {
        vm.prank(provider);
        auctionId = auction.startAuction(
            "ETH/USD",
            "https://api.example/eth",
            "ethereum.usd",
            8,
            10 ether,
            2 ether,
            1 ether,
            15
        );
    }
}
