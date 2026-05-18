// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {SomniaEventHandler} from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";
import {SomniaExtensions} from "@somnia-chain/reactivity-contracts/contracts/interfaces/SomniaExtensions.sol";
import {IDutchAuction} from "../interface/IDutchAuction.sol";
import {IConsumerHandler} from "../interface/IConsumerHandler.sol";

contract ConsumerHandler is SomniaEventHandler, IConsumerHandler {
    bytes32 private constant PRICE_TICK_TOPIC =
        keccak256("PriceTick(uint256,uint256,uint256)");
    bytes32 private constant DATA_DELIVERED_TOPIC =
        keccak256("DataDelivered(uint256,address,uint256,uint256)");

    error OnlyOwner();
    error ZeroAddress();
    error EmptyDataType();

    address public immutable OWNER;
    address public immutable DUTCH_AUCTION;
    address public immutable DATA_PROVIDER;

    uint256 public snapThreshold;
    string public targetDataType;
    uint256 public budget;
    uint256 public spent;

    uint256 public priceTickSubId;
    uint256 public dataDeliveredSubId;

    bool public snapped;
    bool public completed;

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    constructor(
        address dutchAuction_,
        address dataProvider_,
        uint256 snapThreshold_,
        string memory targetDataType_,
        uint64 gasLimit
    ) payable {
        if (dutchAuction_ == address(0) || dataProvider_ == address(0))
            revert ZeroAddress();
        if (bytes(targetDataType_).length == 0) revert EmptyDataType();

        OWNER = msg.sender;
        DUTCH_AUCTION = dutchAuction_;
        DATA_PROVIDER = dataProvider_;
        snapThreshold = snapThreshold_;
        targetDataType = targetDataType_;
        budget = msg.value - 32 ether;

        SomniaExtensions.SubscriptionOptions memory options = SomniaExtensions
            .SubscriptionOptions({
                priorityFeePerGas: 1,
                maxFeePerGas: 0,
                gasLimit: gasLimit
            });

        SomniaExtensions.SubscriptionFilter memory tickFilter = SomniaExtensions
            .SubscriptionFilter({
                eventTopics: [
                    PRICE_TICK_TOPIC,
                    bytes32(0),
                    bytes32(0),
                    bytes32(0)
                ],
                origin: address(0),
                emitter: dutchAuction_
            });
        priceTickSubId = SomniaExtensions.subscribe(
            address(this),
            tickFilter,
            options
        );

        SomniaExtensions.SubscriptionFilter
            memory deliveryFilter = SomniaExtensions.SubscriptionFilter({
                eventTopics: [
                    DATA_DELIVERED_TOPIC,
                    bytes32(0),
                    bytes32(0),
                    bytes32(0)
                ],
                origin: address(0),
                emitter: dataProvider_
            });
        dataDeliveredSubId = SomniaExtensions.subscribe(
            address(this),
            deliveryFilter,
            options
        );
    }

    function _onlyOwner() internal view {
        if (msg.sender != OWNER) revert OnlyOwner();
    }

    function _onEvent(
        address emitter,
        bytes32[] calldata eventTopics,
        bytes calldata data
    ) internal override {
        if (emitter == DUTCH_AUCTION && eventTopics[0] == PRICE_TICK_TOPIC) {
            if (snapped) return;
            _handlePriceTick(eventTopics, data);
            return;
        }

        if (emitter == DATA_PROVIDER && eventTopics[0] == DATA_DELIVERED_TOPIC) {
            if (completed) return;
            _handleDataDelivered(eventTopics, data);
        }
    }

    function withdraw() external onlyOwner {
        (bool success, ) = payable(OWNER).call{value: address(this).balance}(
            ""
        );
        require(success);
    }

    function _handlePriceTick(
        bytes32[] calldata eventTopics,
        bytes calldata data
    ) internal {
        uint256 auctionId = uint256(eventTopics[1]);
        (uint256 price, ) = abi.decode(data, (uint256, uint256));
        IDutchAuction.Auction memory auction_ = IDutchAuction(DUTCH_AUCTION)
            .getAuction(auctionId);

        if (
            keccak256(bytes(auction_.dataType)) !=
            keccak256(bytes(targetDataType))
        ) {
            return;
        }

        if (price <= snapThreshold && address(this).balance >= price) {
            snapped = true;
            spent += price;
            SomniaExtensions.unsubscribe(priceTickSubId);
            IDutchAuction(DUTCH_AUCTION).snap{value: price}(auctionId);
            emit Snapped(auctionId, price);
        }
    }

    function _handleDataDelivered(
        bytes32[] calldata eventTopics,
        bytes calldata data
    ) internal {
        address consumer = address(uint160(uint256(eventTopics[2])));
        if (consumer != address(this)) return;

        (uint256 price, ) = abi.decode(data, (uint256, uint256));
        uint256 auctionId = uint256(eventTopics[1]);

        completed = true;
        SomniaExtensions.unsubscribe(dataDeliveredSubId);
        emit DataReceived(auctionId, price);
    }

    receive() external payable {}
}
