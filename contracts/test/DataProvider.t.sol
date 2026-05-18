// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DataProvider, IJsonApiAgent} from "../src/DataProvider.sol";
import {IDutchAuction} from "../interface/IDutchAuction.sol";

contract MockPlatform {
    uint256 public nextRequestId = 77;
    uint256 public requestDeposit = 0.03 ether;
    uint256 public lastAgentId;
    address public lastCallbackAddress;
    bytes4 public lastCallbackSelector;
    bytes public lastPayload;
    uint256 public lastValue;

    function createRequest(
        uint256 agentId,
        address callbackAddress,
        bytes4 callbackSelector,
        bytes calldata payload
    ) external payable returns (uint256 requestId) {
        lastAgentId = agentId;
        lastCallbackAddress = callbackAddress;
        lastCallbackSelector = callbackSelector;
        lastPayload = payload;
        lastValue = msg.value;
        requestId = nextRequestId;
    }

    function getRequestDeposit() external view returns (uint256) {
        return requestDeposit;
    }
}

contract MockEscrowForDataProvider {
    uint256 public lastReleasedAuctionId;

    function release(uint256 auctionId) external {
        lastReleasedAuctionId = auctionId;
    }
}

contract MockAuctionForDataProvider {
    IDutchAuction.Auction private auction_;

    function setAuction(IDutchAuction.Auction memory newAuction) external {
        auction_ = newAuction;
    }

    function getAuction(uint256) external view returns (IDutchAuction.Auction memory) {
        return auction_;
    }
}

contract DataProviderTest is Test {
    event DataRequested(uint256 indexed auctionId, uint256 indexed requestId);
    event DataDelivered(uint256 indexed auctionId, address indexed consumer, uint256 price, uint256 timestamp);
    event DataFailed(uint256 indexed auctionId, uint8 status);

    MockPlatform public platform;
    MockEscrowForDataProvider public escrow;
    MockAuctionForDataProvider public auction;
    DataProvider public dataProvider;

    address public provider = address(0xBEEF);
    address public buyer = address(0xCAFE);
    uint256 public constant AGENT_ID = 13174292974160097713;
    uint256 public constant EXPECTED_DEPOSIT = 0.12 ether;

    function setUp() public {
        platform = new MockPlatform();
        escrow = new MockEscrowForDataProvider();
        auction = new MockAuctionForDataProvider();
        dataProvider = new DataProvider(address(platform), AGENT_ID, address(escrow), address(auction));
    }

    function test_constructorRejectsInvalidInputs() public {
        vm.expectRevert(DataProvider.ZeroAddress.selector);
        new DataProvider(address(0), AGENT_ID, address(escrow), address(auction));

        vm.expectRevert(DataProvider.InvalidAgentId.selector);
        new DataProvider(address(platform), 0, address(escrow), address(auction));
    }

    function test_fulfillOrderBuildsRequestFromAuctionMetadata() public {
        auction.setAuction(_snappedAuction("ethereum.usd", 8));

        vm.deal(provider, 1 ether);
        vm.prank(provider);
        vm.expectEmit(true, true, false, false);
        emit DataRequested(1, 77);
        dataProvider.fulfillOrder{value: EXPECTED_DEPOSIT}(1);

        assertEq(platform.lastAgentId(), AGENT_ID);
        assertEq(platform.lastCallbackAddress(), address(dataProvider));
        assertEq(platform.lastCallbackSelector(), dataProvider.handleResponse.selector);
        assertEq(platform.lastValue(), EXPECTED_DEPOSIT);
        assertEq(dataProvider.requestToAuction(77), 1);
        assertTrue(dataProvider.pendingRequests(77));

        bytes memory expectedPayload = abi.encodeWithSelector(
            IJsonApiAgent.fetchUint.selector, "https://api.example/eth", "ethereum.usd", uint8(8)
        );
        assertEq(platform.lastPayload(), expectedPayload);
    }

    function test_fulfillOrderUsesSelectorAndDecimalsStoredOnAuction() public {
        auction.setAuction(_snappedAuction("coins.solana.price", 6));

        vm.deal(provider, 1 ether);
        vm.prank(provider);
        dataProvider.fulfillOrder{value: EXPECTED_DEPOSIT}(1);

        bytes memory expectedPayload = abi.encodeWithSelector(
            IJsonApiAgent.fetchUint.selector, "https://api.example/eth", "coins.solana.price", uint8(6)
        );
        assertEq(platform.lastPayload(), expectedPayload);
    }

    function test_fulfillOrderRevertsForUnauthorizedAuctionStateOrLowDeposit() public {
        vm.deal(provider, 1 ether);
        vm.deal(buyer, 1 ether);

        auction.setAuction(_activeAuction());
        vm.prank(provider);
        vm.expectRevert(DataProvider.AuctionNotSnapped.selector);
        dataProvider.fulfillOrder{value: EXPECTED_DEPOSIT}(1);

        auction.setAuction(_snappedAuction("ethereum.usd", 8));
        vm.prank(buyer);
        vm.expectRevert(DataProvider.OnlyProvider.selector);
        dataProvider.fulfillOrder{value: EXPECTED_DEPOSIT}(1);

        vm.prank(provider);
        vm.expectRevert(DataProvider.InsufficientAgentCallDeposit.selector);
        dataProvider.fulfillOrder{value: EXPECTED_DEPOSIT - 1}(1);
    }

    function test_fulfillOrderRefundsExcess() public {
        auction.setAuction(_snappedAuction("ethereum.usd", 8));
        vm.deal(provider, 1 ether);

        uint256 balanceBefore = provider.balance;
        vm.prank(provider);
        dataProvider.fulfillOrder{value: 0.2 ether}(1);

        assertEq(provider.balance, balanceBefore - EXPECTED_DEPOSIT);
    }

    function test_handleResponseReleasesEscrowOnSuccess() public {
        auction.setAuction(_snappedAuction("ethereum.usd", 8));

        vm.deal(provider, 1 ether);
        vm.prank(provider);
        dataProvider.fulfillOrder{value: EXPECTED_DEPOSIT}(1);

        DataProvider.Response[] memory responses = new DataProvider.Response[](1);
        responses[0] = DataProvider.Response({
            validator: address(0x1234),
            result: abi.encode(uint256(2500e8)),
            status: DataProvider.ResponseStatus.Success,
            receipt: 0,
            timestamp: block.timestamp,
            executionCost: 0
        });

        vm.prank(address(platform));
        vm.expectEmit(true, true, false, false);
        emit DataDelivered(1, buyer, 2500e8, block.timestamp);
        dataProvider.handleResponse(77, responses, DataProvider.ResponseStatus.Success, _emptyRequest());

        assertEq(escrow.lastReleasedAuctionId(), 1);
        assertFalse(dataProvider.pendingRequests(77));
    }

    function test_handleResponseEmitsFailureWithoutReleasingEscrow() public {
        auction.setAuction(_snappedAuction("ethereum.usd", 8));

        vm.deal(provider, 1 ether);
        vm.prank(provider);
        dataProvider.fulfillOrder{value: EXPECTED_DEPOSIT}(1);

        DataProvider.Response[] memory responses = new DataProvider.Response[](0);

        vm.prank(address(platform));
        vm.expectEmit(true, false, false, true);
        emit DataFailed(1, uint8(DataProvider.ResponseStatus.Failed));
        dataProvider.handleResponse(77, responses, DataProvider.ResponseStatus.Failed, _emptyRequest());

        assertEq(escrow.lastReleasedAuctionId(), 0);
        assertFalse(dataProvider.pendingRequests(77));
    }

    function test_handleResponseRevertsForUnauthorizedOrUnknownRequest() public {
        DataProvider.Response[] memory responses = new DataProvider.Response[](0);

        vm.prank(provider);
        vm.expectRevert(DataProvider.OnlyPlatform.selector);
        dataProvider.handleResponse(77, responses, DataProvider.ResponseStatus.Failed, _emptyRequest());

        vm.prank(address(platform));
        vm.expectRevert(DataProvider.UnknownRequest.selector);
        dataProvider.handleResponse(77, responses, DataProvider.ResponseStatus.Failed, _emptyRequest());
    }

    function _activeAuction() internal view returns (IDutchAuction.Auction memory) {
        return IDutchAuction.Auction({
            id: 1,
            provider: provider,
            dataType: "ETH/USD",
            apiUrl: "https://api.example/eth",
            jsonSelector: "ethereum.usd",
            decimals: 8,
            startPrice: 10 ether,
            floorPrice: 2 ether,
            currentPrice: 9 ether,
            priceStep: 1 ether,
            startBlock: 1,
            timeoutBlocks: 15,
            status: IDutchAuction.AuctionStatus.Active,
            winner: address(0),
            escrowRef: 0
        });
    }

    function _snappedAuction(
        string memory jsonSelector,
        uint8 decimals
    ) internal view returns (IDutchAuction.Auction memory) {
        return IDutchAuction.Auction({
            id: 1,
            provider: provider,
            dataType: "ETH/USD",
            apiUrl: "https://api.example/eth",
            jsonSelector: jsonSelector,
            decimals: decimals,
            startPrice: 10 ether,
            floorPrice: 2 ether,
            currentPrice: 9 ether,
            priceStep: 1 ether,
            startBlock: 1,
            timeoutBlocks: 15,
            status: IDutchAuction.AuctionStatus.Snapped,
            winner: buyer,
            escrowRef: 1
        });
    }

    function _emptyRequest() internal pure returns (DataProvider.Request memory details) {}
}
