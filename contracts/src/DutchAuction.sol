// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IDutchAuction} from "../interface/IDutchAuction.sol";
import {IEscrow} from "../interface/IEscrow.sol";

contract DutchAuction is IDutchAuction {
    error OnlyClock();
    error AuctionNotFound();
    error AuctionNotActive();
    error EmptyDataType();
    error EmptyApiUrl();
    error EmptyJsonSelector();
    error InvalidPriceRange();
    error InvalidPriceStep();
    error InvalidTimeout();
    error InsufficientPayment();
    error RefundFailed();
    error ReentrancyGuard();

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCount;
    address public auctionClock;
    IEscrow public escrow;

    uint256[] private activeAuctionIds;
    mapping(uint256 => uint256) private activeAuctionIndexPlusOne;

    bool private locked;

    modifier onlyClock() {
        _onlyClock();
        _;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    constructor(address auctionClock_, address escrow_) {
        auctionClock = auctionClock_;
        escrow = IEscrow(escrow_);
    }

    function _nonReentrantBefore() internal {
        if (locked) revert ReentrancyGuard();
        locked = true;
    }

    function _nonReentrantAfter() internal {
        locked = false;
    }

    function _onlyClock() internal view {
        if (msg.sender != auctionClock) revert OnlyClock();
    }

    function startAuction(
        string calldata dataType,
        string calldata apiUrl,
        string calldata jsonSelector,
        uint8 decimals,
        uint256 startPrice,
        uint256 floorPrice,
        uint256 priceStep,
        uint256 timeoutBlocks
    ) external returns (uint256 auctionId) {
        if (bytes(dataType).length == 0) revert EmptyDataType();
        if (bytes(apiUrl).length == 0) revert EmptyApiUrl();
        if (bytes(jsonSelector).length == 0) revert EmptyJsonSelector();
        if (startPrice < floorPrice) revert InvalidPriceRange();
        if (priceStep == 0) revert InvalidPriceStep();
        if (timeoutBlocks == 0) revert InvalidTimeout();

        auctionId = ++auctionCount;
        Auction storage auction_ = auctions[auctionId];
        auction_.id = auctionId;
        auction_.provider = msg.sender;
        auction_.dataType = dataType;
        auction_.apiUrl = apiUrl;
        auction_.jsonSelector = jsonSelector;
        auction_.decimals = decimals;
        auction_.startPrice = startPrice;
        auction_.floorPrice = floorPrice;
        auction_.currentPrice = startPrice;
        auction_.priceStep = priceStep;
        auction_.startBlock = block.number;
        auction_.timeoutBlocks = timeoutBlocks;
        auction_.status = AuctionStatus.Active;

        activeAuctionIndexPlusOne[auctionId] = activeAuctionIds.length + 1;
        activeAuctionIds.push(auctionId);

        emit AuctionStarted(auctionId, msg.sender, dataType, startPrice);
        emit PriceTick(auctionId, startPrice, block.number);
    }

    function dropPrice(uint256 auctionId) external onlyClock {
        Auction storage auction_ = _getExistingAuction(auctionId);
        if (auction_.status != AuctionStatus.Active) revert AuctionNotActive();

        if (block.number > auction_.startBlock + auction_.timeoutBlocks) {
            auction_.status = AuctionStatus.Expired;
            _removeActiveAuction(auctionId);
            emit AuctionExpired(auctionId);
            return;
        }

        if (auction_.currentPrice <= auction_.floorPrice + auction_.priceStep) {
            auction_.currentPrice = auction_.floorPrice;
        } else {
            auction_.currentPrice -= auction_.priceStep;
        }

        emit PriceTick(auctionId, auction_.currentPrice, block.number);
    }

    function snap(
        uint256 auctionId
    ) external payable nonReentrant returns (bool) {
        Auction storage auction_ = _getExistingAuction(auctionId);
        if (auction_.status != AuctionStatus.Active) revert AuctionNotActive();
        if (msg.value < auction_.currentPrice) revert InsufficientPayment();

        uint256 currentPrice = auction_.currentPrice;
        uint256 refund = msg.value - currentPrice;

        auction_.status = AuctionStatus.Snapped;
        auction_.winner = msg.sender;
        auction_.escrowRef = auctionId;
        _removeActiveAuction(auctionId);

        escrow.lockPayment{value: currentPrice}(
            auctionId,
            msg.sender,
            auction_.provider,
            auction_.timeoutBlocks
        );

        if (refund != 0) {
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert RefundFailed();
        }

        emit AuctionSnapped(auctionId, msg.sender, currentPrice);
        return true;
    }

    function getActiveAuctions() external view returns (uint256[] memory) {
        return activeAuctionIds;
    }

    function getAuction(
        uint256 auctionId
    ) external view returns (Auction memory) {
        return _getExistingAuction(auctionId);
    }

    function _getExistingAuction(
        uint256 auctionId
    ) internal view returns (Auction storage auction_) {
        if (auctionId == 0 || auctionId > auctionCount)
            revert AuctionNotFound();
        auction_ = auctions[auctionId];
    }

    function _removeActiveAuction(uint256 auctionId) internal {
        uint256 indexPlusOne = activeAuctionIndexPlusOne[auctionId];
        if (indexPlusOne == 0) {
            return;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = activeAuctionIds.length - 1;

        if (index != lastIndex) {
            uint256 lastAuctionId = activeAuctionIds[lastIndex];
            activeAuctionIds[index] = lastAuctionId;
            activeAuctionIndexPlusOne[lastAuctionId] = index + 1;
        }

        activeAuctionIds.pop();
        delete activeAuctionIndexPlusOne[auctionId];
    }
}
