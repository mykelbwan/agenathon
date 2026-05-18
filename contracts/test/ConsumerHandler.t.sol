// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ConsumerHandler} from "../src/ConsumerHandler.sol";
import {IDutchAuction} from "../interface/IDutchAuction.sol";
import {SomniaExtensions} from "@somnia-chain/reactivity-contracts/contracts/interfaces/SomniaExtensions.sol";
import {ISomniaReactivityPrecompile} from "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaReactivityPrecompile.sol";

contract MockAuctionForConsumer {
    uint256 public lastSnappedAuctionId;
    uint256 public lastSnapValue;
    string public currentDataType = "ETH/USD";

    function snap(uint256 auctionId) external payable returns (bool) {
        lastSnappedAuctionId = auctionId;
        lastSnapValue = msg.value;
        return true;
    }

    function setDataType(string memory dataType_) external {
        currentDataType = dataType_;
    }

    function getAuction(uint256 auctionId) external view returns (IDutchAuction.Auction memory) {
        return IDutchAuction.Auction({
            id: auctionId,
            provider: address(0xBEEF),
            dataType: currentDataType,
            apiUrl: "",
            jsonSelector: "",
            decimals: 8,
            startPrice: 0,
            floorPrice: 0,
            currentPrice: 0,
            priceStep: 0,
            startBlock: 0,
            timeoutBlocks: 0,
            status: IDutchAuction.AuctionStatus.Active,
            winner: address(0),
            escrowRef: 0
        });
    }
}

contract MockReactivityPrecompileForConsumer {
    uint256 public nextSubscriptionId = 1;
    uint256 public unsubscribedId;

    struct StoredSubscription {
        bytes32[4] eventTopics;
        address origin;
        address caller;
        address emitter;
        address handlerContractAddress;
        bytes4 handlerFunctionSelector;
        uint64 priorityFeePerGas;
        uint64 maxFeePerGas;
        uint64 gasLimit;
        bool isGuaranteed;
        bool isCoalesced;
    }

    StoredSubscription[] private subscriptions;

    function subscribe(
        ISomniaReactivityPrecompile.SubscriptionData calldata subscriptionData
    ) external returns (uint256 subscriptionId) {
        subscriptions.push(
            StoredSubscription({
                eventTopics: subscriptionData.eventTopics,
                origin: subscriptionData.origin,
                caller: subscriptionData.caller,
                emitter: subscriptionData.emitter,
                handlerContractAddress: subscriptionData.handlerContractAddress,
                handlerFunctionSelector: subscriptionData.handlerFunctionSelector,
                priorityFeePerGas: subscriptionData.priorityFeePerGas,
                maxFeePerGas: subscriptionData.maxFeePerGas,
                gasLimit: subscriptionData.gasLimit,
                isGuaranteed: subscriptionData.isGuaranteed,
                isCoalesced: subscriptionData.isCoalesced
            })
        );
        subscriptionId = nextSubscriptionId++;
    }

    function unsubscribe(uint256 subscriptionId) external {
        unsubscribedId = subscriptionId;
    }

    function getSubscriptionCount() external view returns (uint256) {
        return subscriptions.length;
    }

    function getSubscription(
        uint256 index
    )
        external
        view
        returns (
            bytes32[4] memory eventTopics,
            address origin,
            address caller,
            address emitter,
            address handlerContractAddress,
            bytes4 handlerFunctionSelector,
            uint64 priorityFeePerGas,
            uint64 maxFeePerGas,
            uint64 gasLimit,
            bool isGuaranteed,
            bool isCoalesced
        )
    {
        StoredSubscription storage sub = subscriptions[index];
        return (
            sub.eventTopics,
            sub.origin,
            sub.caller,
            sub.emitter,
            sub.handlerContractAddress,
            sub.handlerFunctionSelector,
            sub.priorityFeePerGas,
            sub.maxFeePerGas,
            sub.gasLimit,
            sub.isGuaranteed,
            sub.isCoalesced
        );
    }
}

contract ConsumerHandlerTest is Test {
    event Snapped(uint256 indexed auctionId, uint256 price);
    event DataReceived(uint256 indexed auctionId, uint256 price);

    bytes32 internal constant PRICE_TICK_TOPIC = keccak256("PriceTick(uint256,uint256,uint256)");
    bytes32 internal constant DATA_DELIVERED_TOPIC = keccak256("DataDelivered(uint256,address,uint256,uint256)");

    ConsumerHandler public consumerHandler;
    MockAuctionForConsumer public auction;
    MockReactivityPrecompileForConsumer public precompileImplementation;
    MockReactivityPrecompileForConsumer public precompile;

    address public owner = address(0xA11CE);
    address public dataProvider = address(0xDADA);
    uint64 public constant GAS_LIMIT = 2_000_000;

    function setUp() public {
        auction = new MockAuctionForConsumer();
        precompileImplementation = new MockReactivityPrecompileForConsumer();

        vm.etch(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS, address(precompileImplementation).code);
        vm.store(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS, bytes32(0), bytes32(uint256(1)));
        precompile = MockReactivityPrecompileForConsumer(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);

        vm.deal(owner, 50 ether);
        vm.prank(owner);
        consumerHandler = new ConsumerHandler{value: 32 ether + 10 ether}(
            address(auction), dataProvider, 3 ether, "ETH/USD", GAS_LIMIT
        );
    }

    function test_constructorCreatesTwoSubscriptionsAndStoresState() public view {
        assertEq(consumerHandler.OWNER(), owner);
        assertEq(consumerHandler.DUTCH_AUCTION(), address(auction));
        assertEq(consumerHandler.DATA_PROVIDER(), dataProvider);
        assertEq(consumerHandler.snapThreshold(), 3 ether);
        assertEq(consumerHandler.targetDataType(), "ETH/USD");
        assertEq(consumerHandler.budget(), 10 ether);
        assertEq(consumerHandler.priceTickSubId(), 1);
        assertEq(consumerHandler.dataDeliveredSubId(), 2);
        assertFalse(consumerHandler.snapped());
        assertFalse(consumerHandler.completed());

        assertEq(precompile.getSubscriptionCount(), 2);
    }

    function test_priceTickBelowThresholdSnapsAndUnsubscribesPriceFeed() public {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = PRICE_TICK_TOPIC;
        topics[1] = bytes32(uint256(7));

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        vm.expectEmit(true, false, false, true);
        emit Snapped(7, 3 ether);
        consumerHandler.onEvent(address(auction), topics, abi.encode(uint256(3 ether), uint256(block.number)));

        assertTrue(consumerHandler.snapped());
        assertFalse(consumerHandler.completed());
        assertEq(precompile.unsubscribedId(), 1);
        assertEq(auction.lastSnappedAuctionId(), 7);
        assertEq(auction.lastSnapValue(), 3 ether);
    }

    function test_priceTickAboveThresholdDoesNothing() public {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = PRICE_TICK_TOPIC;
        topics[1] = bytes32(uint256(7));

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        consumerHandler.onEvent(address(auction), topics, abi.encode(uint256(4 ether), uint256(block.number)));

        assertFalse(consumerHandler.snapped());
        assertEq(auction.lastSnappedAuctionId(), 0);
    }

    function test_priceTickForDifferentDataTypeIsIgnored() public {
        auction.setDataType("BTC/USD");

        bytes32[] memory topics = new bytes32[](2);
        topics[0] = PRICE_TICK_TOPIC;
        topics[1] = bytes32(uint256(7));

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        consumerHandler.onEvent(address(auction), topics, abi.encode(uint256(3 ether), uint256(block.number)));

        assertFalse(consumerHandler.snapped());
        assertEq(auction.lastSnappedAuctionId(), 0);
    }

    function test_dataDeliveredMarksCompletedAndUnsubscribesDeliveryFeed() public {
        _snapAuction();

        bytes32[] memory topics = new bytes32[](3);
        topics[0] = DATA_DELIVERED_TOPIC;
        topics[1] = bytes32(uint256(7));
        topics[2] = bytes32(uint256(uint160(address(consumerHandler))));

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        vm.expectEmit(true, false, false, true);
        emit DataReceived(7, 2500e8);
        consumerHandler.onEvent(dataProvider, topics, abi.encode(uint256(2500e8), uint256(block.timestamp)));

        assertTrue(consumerHandler.snapped());
        assertTrue(consumerHandler.completed());
        assertEq(precompile.unsubscribedId(), 2);
    }

    function test_dataDeliveredForAnotherConsumerIsIgnored() public {
        _snapAuction();

        bytes32[] memory topics = new bytes32[](3);
        topics[0] = DATA_DELIVERED_TOPIC;
        topics[1] = bytes32(uint256(7));
        topics[2] = bytes32(uint256(uint160(address(0x9999))));

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        consumerHandler.onEvent(dataProvider, topics, abi.encode(uint256(2500e8), uint256(block.timestamp)));

        assertFalse(consumerHandler.completed());
    }

    function test_ownerCanWithdrawUnspentBudget() public {
        uint256 ownerBalanceBefore = owner.balance;
        uint256 handlerBalanceBefore = address(consumerHandler).balance;

        vm.prank(owner);
        consumerHandler.withdraw();

        assertEq(owner.balance, ownerBalanceBefore + handlerBalanceBefore);
        assertEq(address(consumerHandler).balance, 0);
    }

    function test_withdrawRevertsForNonOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(ConsumerHandler.OnlyOwner.selector);
        consumerHandler.withdraw();
    }

    function _snapAuction() internal {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = PRICE_TICK_TOPIC;
        topics[1] = bytes32(uint256(7));

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        consumerHandler.onEvent(address(auction), topics, abi.encode(uint256(3 ether), uint256(block.number)));
    }
}
