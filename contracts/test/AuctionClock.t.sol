// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {AuctionClock} from "../src/AuctionClock.sol";
import {SomniaExtensions} from "@somnia-chain/reactivity-contracts/contracts/interfaces/SomniaExtensions.sol";
import {ISomniaReactivityPrecompile} from "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaReactivityPrecompile.sol";

contract MockDutchAuctionForClock {
    uint256[] private activeAuctions;
    uint256[] public dropped;
    mapping(uint256 => bool) public shouldRevert;

    function setActiveAuctions(uint256[] memory newActiveAuctions) external {
        delete activeAuctions;
        for (uint256 i = 0; i < newActiveAuctions.length; i++) {
            activeAuctions.push(newActiveAuctions[i]);
        }
    }

    function setShouldRevert(uint256 auctionId, bool value) external {
        shouldRevert[auctionId] = value;
    }

    function getActiveAuctions() external view returns (uint256[] memory) {
        return activeAuctions;
    }

    function dropPrice(uint256 auctionId) external {
        if (shouldRevert[auctionId]) revert("drop failed");
        dropped.push(auctionId);
    }

    function droppedCount() external view returns (uint256) {
        return dropped.length;
    }
}

contract MockReactivityPrecompile {
    uint256 public nextSubscriptionId = 1;
    ISomniaReactivityPrecompile.SubscriptionData private lastSubscriptionData;

    function subscribe(
        ISomniaReactivityPrecompile.SubscriptionData calldata subscriptionData
    ) external returns (uint256 subscriptionId) {
        lastSubscriptionData = subscriptionData;
        subscriptionId = nextSubscriptionId++;
    }

    function unsubscribe(uint256) external {}

    function getSubscriptionInfo(
        uint256
    )
        external
        pure
        returns (
            ISomniaReactivityPrecompile.SubscriptionData
                memory subscriptionData,
            address owner
        )
    {}

    function getLastSubscriptionData()
        external
        view
        returns (
            ISomniaReactivityPrecompile.SubscriptionData memory subscriptionData
        )
    {
        return lastSubscriptionData;
    }
}

contract AuctionClockTest is Test {
    AuctionClock public clock;
    MockDutchAuctionForClock public auction;
    MockReactivityPrecompile public precompileImplementation;
    MockReactivityPrecompile public precompile;

    uint64 public constant GAS_LIMIT = 5_000_000;

    function setUp() public {
        auction = new MockDutchAuctionForClock();
        precompileImplementation = new MockReactivityPrecompile();

        vm.etch(
            SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS,
            address(precompileImplementation).code
        );
        vm.store(
            SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS,
            bytes32(0),
            bytes32(uint256(1))
        );
        precompile = MockReactivityPrecompile(
            SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS
        );
        vm.deal(address(this), 40 ether);

        clock = new AuctionClock{value: 32 ether}(address(auction), GAS_LIMIT);
    }

    function test_constructorSubscribesToRecurringBlockTick() public view {
        assertEq(clock.subscriptionId(), 1);

        ISomniaReactivityPrecompile.SubscriptionData memory data = precompile
            .getLastSubscriptionData();
        assertEq(
            uint256(data.eventTopics[0]),
            uint256(ISomniaReactivityPrecompile.BlockTick.selector)
        );
        assertEq(uint256(data.eventTopics[1]), 0);
        assertEq(data.origin, address(0));
        assertEq(
            data.emitter,
            SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS
        );
        assertEq(data.handlerContractAddress, address(clock));
        assertEq(data.gasLimit, GAS_LIMIT);
        assertEq(data.priorityFeePerGas, 1);
        assertEq(data.maxFeePerGas, 0);
    }

    function test_onEventDropsAllActiveAuctions() public {
        uint256[] memory active = new uint256[](3);
        active[0] = 1;
        active[1] = 2;
        active[2] = 3;
        auction.setActiveAuctions(active);

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        clock.onEvent(
            SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS,
            _blockTickTopics(),
            ""
        );

        assertEq(auction.dropped(0), 1);
        assertEq(auction.dropped(1), 2);
        assertEq(auction.dropped(2), 3);
        assertEq(auction.droppedCount(), 3);
    }

    function test_onEventContinuesWhenOneAuctionDropReverts() public {
        uint256[] memory active = new uint256[](3);
        active[0] = 10;
        active[1] = 11;
        active[2] = 12;
        auction.setActiveAuctions(active);
        auction.setShouldRevert(11, true);

        vm.prank(SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS);
        clock.onEvent(
            SomniaExtensions.SOMNIA_REACTIVITY_PRECOMPILE_ADDRESS,
            _blockTickTopics(),
            ""
        );

        assertEq(auction.dropped(0), 10);
        assertEq(auction.dropped(1), 12);
        assertEq(auction.droppedCount(), 2);
    }

    function _blockTickTopics()
        internal
        pure
        returns (bytes32[] memory topics)
    {
        topics = new bytes32[](1);
        topics[0] = ISomniaReactivityPrecompile.BlockTick.selector;
    }
}
